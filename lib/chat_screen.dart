import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agora_rtm/agora_rtm.dart';
import 'api/dio_client.dart';

/// 全局 RTM 管理器 (单例)
class RtmManager {
  static final RtmManager _instance = RtmManager._internal();
  factory RtmManager() => _instance;
  RtmManager._internal();

  RtmClient? _client;
  // UI 消息回调: (String message, String peerId)
  Function(String, String)? onMessageReceived;
  // 历史消息同步完成回调
  VoidCallback? onHistorySynced;
  // 消息缓存: peerId -> List<MessageJson> (包含 _isMe 字段)
  final Map<String, List<Map<String, dynamic>>> _messageCache = {};
  
  String? _currentUid;

  // 未读消息计数: orderId -> count
  final ValueNotifier<Map<String, int>> unreadCountsNotifier = ValueNotifier({});
  String? _activeOrderId; // 当前处于活跃状态的聊天订单ID

  bool get isLogin => _client != null;

  /// 初始化并登录 RTM
  Future<void> init(String appId, String token, String uid) async {
    if (_client != null) return; // 已连接则跳过

    _currentUid = uid;
    
    // [新增] 从服务端拉取未读计数快照并覆盖本地 (服务端一致性)
    await _fetchServerUnreadCounts();

    debugPrint("🔄 [RTM] 开始全局初始化: UID=$uid");
    try {
      // RTM 2.x 初始化
      // 1. 使用 RTM() 顶层函数创建实例，appId 和 userId 作为位置参数传递
      final (status, client) = await RTM(appId, uid, config: const RtmConfig(areaCode: {RtmAreaCode.na}));

      if (status.error == true) {
        throw Exception("RTM Create failed: ${status.reason}");
      }
      _client = client;

      // 2. 设置事件监听 (替代 RtmEventHandler)
      _client!.addListener(message: (MessageEvent event) {
        // 消息内容是 Uint8List，需要解码
        final text = event.message != null ? utf8.decode(event.message!) : "";
        final peerId = event.publisher ?? "";
        _handleIncomingMessage(text, peerId);
      });

      // 3. 登录 (解构返回值)
      final (loginStatus, _) = await _client!.login(token);
      if (loginStatus.error == true) {
        throw Exception("RTM Login failed: ${loginStatus.reason}");
      }
      
      debugPrint("✅ [RTM] 全局登录成功");
      // 启动云端增量同步
      _syncCloudHistory();
    } catch (e) {
      debugPrint("❌ [RTM] 全局登录失败: $e");
      _client = null;
    }
  }

  /// 从服务端拉取未读计数
  Future<void> _fetchServerUnreadCounts() async {
    final counts = await DioClient().getUnreadCounts();
    // 直接覆盖本地变量，以服务端为准
    unreadCountsNotifier.value = counts;
  }

  Future<void> _handleIncomingMessage(String text, String peerId, {bool isOfflineMessage = false}) async {
    debugPrint("📩 [RTM] 收到消息 from $peerId: $text");
    
    // 1. 存入缓存
    try {
      final Map<String, dynamic> map = jsonDecode(text);
      map['_isMe'] = false; // 标记为接收

      // 简单去重: 检查是否已存在相同 timestamp 和 content 的消息
      if (_messageCache.containsKey(peerId)) {
        final exists = _messageCache[peerId]!.any((m) =>
            m['timestamp'] == map['timestamp'] && m['content'] == map['content']);
        if (exists) {
          debugPrint("⚠️ [RTM] 忽略重复消息: ${map['content']}");
          return;
        }
      }

      if (!_messageCache.containsKey(peerId)) {
        _messageCache[peerId] = [];
      }
      _messageCache[peerId]!.add(map);

      // 2. 更新未读计数
      final String orderId = map['order_id'].toString();
      // 如果当前不在该订单的聊天窗口，则增加未读计数
      if (_activeOrderId != orderId) {
        final current = Map<String, int>.from(unreadCountsNotifier.value);
        current[orderId] = (current[orderId] ?? 0) + 1;
        unreadCountsNotifier.value = current;
      } else {
        // [新增] 如果在聊天窗口，立即发送 ACK
        final int msgId = map['msg_id'] as int? ?? 0;
        if (msgId > 0) {
          DioClient().sendReadAck(int.parse(orderId), msgId);
        }
      }
    } catch (e) {
      debugPrint("❌ [RTM] 缓存接收消息失败: $e");
    }

    // 转发给当前的 UI 监听器 (如果有)
    if (onMessageReceived != null) {
      onMessageReceived!(text, peerId);
    }
  }

  /// 从云端增量同步历史消息
  Future<void> _syncCloudHistory() async {
    if (_currentUid == null) return;
    debugPrint("☁️ [Sync] 开始全量同步消息...");

    try {
      // 移除本地缓存后，每次从 0 开始拉取 (或由后端控制默认返回最近 N 条)
      final list = await DioClient().getChatHistory(sinceId: 0);
      if (list.isEmpty) return;

      int maxId = 0;
      bool hasNew = false;

      for (var item in list) {
        final int msgId = item['id'];
        if (msgId > maxId) maxId = msgId; // 仅用于日志记录

        final int orderId = item['order_id'];
        final String senderId = item['sender_id'].toString();
        final String receiverId = item['receiver_id'].toString();
        final String content = item['content'];
        final int timestamp = item['client_timestamp'];
        final String msgType = item['msg_type'] ?? 'text';

        final bool isMe = (senderId == _currentUid);
        // 如果我是发送者，对方是接收者；如果我是接收者，对方是发送者
        final String peerId = isMe ? receiverId : senderId;

        final Map<String, dynamic> localMsg = {
          'order_id': orderId,
          'content': content,
          'type': msgType,
          'timestamp': timestamp,
          '_isMe': isMe,
          'msg_id': msgId
        };

        if (!_messageCache.containsKey(peerId)) {
          _messageCache[peerId] = [];
        }

        // 去重: 根据 msg_id 或 (timestamp + content)
        final exists = _messageCache[peerId]!.any((m) =>
            (m['msg_id'] == msgId) ||
            (m['timestamp'] == timestamp && m['content'] == content));

        if (!exists) {
          _messageCache[peerId]!.add(localMsg);
          hasNew = true;
          // ⚠️ 关键修改: 历史消息同步时不更新未读计数！
          // 因为未读计数已经由 _fetchServerUnreadCounts 准确获取了。
          // 如果这里再 ++，会导致重复计算。 
        }
      }

      if (hasNew) {
        if (onHistorySynced != null) onHistorySynced!();
        debugPrint("✅ [Sync] 同步完成，更新至 ID=$maxId");
        
        // [新增] 如果当前处于某个聊天室，且同步到了该聊天室的消息，尝试更新 ACK
        if (_activeOrderId != null) {
           final currentMax = _getLatestMsgId(_activeOrderId!);
           if (currentMax > 0) {
             DioClient().sendReadAck(int.parse(_activeOrderId!), currentMax);
           }
        }
      }
    } catch (e) {
      debugPrint("❌ [Sync] 同步失败: $e");
    }
  }

  /// 拉取离线消息 (User Channel)
  /// RTM 2.x 不会自动推送离线消息，需要主动拉取 "发给我的" 消息
  Future<void> _pullOfflineMessages(String uid) async {
    if (_client == null) return;
    try {
      debugPrint("📥 [RTM] 开始拉取离线消息 (User Channel)...");
      // 4. getHistory() 返回模块对象，需调用其 getMessages 方法
      final (status, response) = await _client!.getHistory().getMessages(
        uid, // Channel Name = 自己的 UID (User Channel)
        RtmChannelType.user,
        messageCount: 20,
      );

      if (status.error == false && response != null) {
        debugPrint("✅ [RTM] 拉取离线消息成功: 共 ${response.messageList.length} 条");
        // 历史消息默认可能是倒序 (最新的在前)，反转后按时间顺序插入
        for (var msg in response.messageList.reversed) {
          final text = msg.message != null ? utf8.decode(msg.message!) : "";
          final peerId = msg.publisher ?? "";
          debugPrint("   📄 [RTM] 消息详情: 来自=$peerId, 内容=$text");
          await _handleIncomingMessage(text, peerId, isOfflineMessage: true);
        }
      } else {
        debugPrint("❌ [RTM] 拉取离线消息失败: Code=${status.errorCode}, Reason=${status.reason}");
      }
    } catch (e) {
      debugPrint("❌ [RTM] 拉取离线消息异常: $e");
    }
  }

  /// 发送 P2P 消息
  Future<void> sendMessageToPeer(String peerId, String text) async {
    // 1. 解析原始消息并同步到云端
    Map<String, dynamic> msgMap = jsonDecode(text);
    bool cloudSuccess = false;

    try {
      final apiData = {
        "order_id": msgMap['order_id'],
        "content": msgMap['content'],
        "type": msgMap['type'] ?? "text",
        "timestamp": msgMap['timestamp']
      };
      final res = await DioClient().saveChatMessage(apiData);
      if (res != null && res['msg_id'] != null) {
        // 将后端生成的 msg_id 注入到 RTM 消息中，方便接收端去重
        msgMap['msg_id'] = res['msg_id'];
        text = jsonEncode(msgMap);
        cloudSuccess = true;
      }
    } catch (e) {
      debugPrint("⚠️ [RTM] 消息同步云端失败，继续尝试发送 RTM: $e");
    }
    
    // RTM 2.x 发送消息 (User Channel)
    if (_client != null) {
      final (status, _) = await _client!.publish(
        peerId, // channelName = target userId
        text,   // 发送可能包含 msg_id 的 JSON
        channelType: RtmChannelType.user,
        customType: 'PlainText',
        storeInHistory: false, // 5. 直接使用命名参数，移除 PublishOptions
      );

      if (status.error == true) {
        debugPrint("⚠️ [RTM] 发送失败: ${status.errorCode}, ${status.reason}");
        // 如果云端保存成功，则不抛出异常，视为发送成功
        if (!cloudSuccess) {
          throw Exception("发送失败: ${status.errorCode}, ${status.reason}");
        }
      }
    } else if (!cloudSuccess) {
      throw Exception("RTM 服务未连接且云端保存失败");
    }

    // 3. 发送成功后，存入本地缓存
    try {
      msgMap['_isMe'] = true; // 标记为发送
      if (!_messageCache.containsKey(peerId)) {
        _messageCache[peerId] = [];
      }
      _messageCache[peerId]!.add(msgMap);
    } catch (e) {
      debugPrint("❌ [RTM] 缓存发送消息失败: $e");
    }
  }

  /// 获取缓存的消息
  List<Map<String, dynamic>> getMessages(String peerId, String orderId) {
    final list = _messageCache[peerId] ?? [];
    // 根据 orderId 过滤，防止串单
    return list.where((m) => m['order_id'].toString() == orderId.toString()).toList();
  }

  /// 进入聊天窗口 (清除未读 + 发送回执)
  void enterChat(String orderId) {
    _activeOrderId = orderId;
    _clearUnread(orderId);
    
    // 发送已读回执 (告诉后端我读到了哪里)
    final int maxId = _getLatestMsgId(orderId);
    if (maxId > 0) {
      DioClient().sendReadAck(int.parse(orderId), maxId);
    }
  }

  /// 获取指定订单中最大的消息ID
  int _getLatestMsgId(String orderId) {
    int maxId = 0;
    _messageCache.forEach((peerId, msgs) {
      for (var msg in msgs) {
        if (msg['order_id'].toString() == orderId) {
          final id = msg['msg_id'] as int? ?? 0;
          if (id > maxId) maxId = id;
        }
      }
    });
    return maxId;
  }

  /// 离开聊天窗口
  /// 增加 orderId 参数，防止从 聊天B 返回 聊天A 时，聊天B 的销毁误清除了 聊天A 的状态
  void leaveChat(String orderId) {
    if (_activeOrderId == orderId) {
      _activeOrderId = null;
    }
  }

  Future<void> _clearUnread(String orderId) async {
    final current = Map<String, int>.from(unreadCountsNotifier.value);
    if (current.containsKey(orderId)) {
      current.remove(orderId);
      unreadCountsNotifier.value = current;
    }
  }

  /// 登出 (通常在切换账号时调用)
  Future<void> logout() async {
    try {
      await _client?.logout();
      await _client?.release();
      _client = null;
      
      // 清理内存中的用户状态
      _currentUid = null;
      _messageCache.clear();
      unreadCountsNotifier.value = {};
      _activeOrderId = null;
    } catch (e) {
      debugPrint("❌ [RTM] 登出失败: $e");
    }
  }
}

class ChatScreen extends StatefulWidget {
  final int orderId;
  final String currentUserId;
  final String otherUserName;
  final String otherUserId;

  const ChatScreen({
    super.key,
    required this.orderId,
    required this.currentUserId,
    required this.otherUserName,
    required this.otherUserId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  String? _peerUid; // 对方的 RTM UID
  final List<_Message> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // 修复: 延迟执行状态更新，避免在构建期间触发 notifyListeners 导致 "setState during build" 异常
    WidgetsBinding.instance.addPostFrameCallback((_) {
      RtmManager().enterChat(widget.orderId.toString());
    });
    _initAgoraRtm();
  }

  @override
  void dispose() {
    RtmManager().leaveChat(widget.orderId.toString()); // 标记离开当前特定订单
    // 移除监听，但不要断开连接！
    RtmManager().onMessageReceived = null;
    RtmManager().onHistorySynced = null;
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initAgoraRtm() async {
    try {
      // 1. 设置 peerUid (直接从 widget 参数获取)
      _peerUid = widget.otherUserId;

      if (_peerUid!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("聊天参数错误: 对方ID为空")));
        }
        return;
      }

      // 2. 尝试全局登录 (如果尚未登录)
      if (!RtmManager().isLogin) {
        // 如果未登录，需要单独获取 RTM Token
        final rtmData = await DioClient().getRtmToken();
        if (rtmData != null) {
          final String appId = (rtmData['app_id'] ?? "").toString().trim();
          final String rtmToken = (rtmData['token'] ?? rtmData['rtm_token'] ?? "").toString().trim();
          final String uid = (rtmData['uid'] ?? "").toString().trim();
          
          if (appId.isNotEmpty && rtmToken.isNotEmpty && uid.isNotEmpty) {
            await RtmManager().init(appId, rtmToken, uid);
          }
        }
      }

      // 3. 加载本地缓存的历史消息 (确保在 init 之后，因为 init 会加载缓存)
      final history = RtmManager().getMessages(_peerUid!, widget.orderId.toString());
      if (history.isNotEmpty) {
        setState(() {
          _messages.clear();
          for (var map in history) {
            final int ts = (map['timestamp'] as num?)?.toInt() ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
            _messages.add(_Message(
              text: map['content'] ?? '',
              isMe: map['_isMe'] == true,
              timestamp: ts,
            ));
          }
        });
        // 滚动到底部
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          }
        });
      }

      // 4. 注册当前页面的消息监听
      RtmManager().onMessageReceived = (String messageText, String peerId) {
        // 过滤：只处理当前聊天对象的消息
        if (peerId == _peerUid) {
          if (mounted) {
            try {
              final Map<String, dynamic> map = jsonDecode(messageText);
              // 校验 order_id
              if (map['order_id'].toString() == widget.orderId.toString()) {
                final int ts = (map['timestamp'] as num?)?.toInt() ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
                _addMessage(map['content'] ?? '', false, ts);
              }
            } catch (e) {
              _addMessage(messageText, false, DateTime.now().millisecondsSinceEpoch ~/ 1000);
            }
          }
        }
      };

      // 5. 注册历史同步回调 (当后台增量拉取完成后刷新 UI)
      RtmManager().onHistorySynced = () {
        if (mounted) _reloadHistory();
      };

    } on MissingPluginException {
      debugPrint("❌ RTM 插件未加载: 请停止应用并重新编译运行 (Hot Restart 无法加载新插件)");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("请完全重启应用以加载新插件")));
      }
    } catch (e) {
      debugPrint("❌ RTM 初始化失败: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("聊天服务连接失败: $e")));
      }
    }
  }

  void _reloadHistory() {
    final history = RtmManager().getMessages(widget.otherUserId, widget.orderId.toString());
    setState(() {
      _messages.clear();
      for (var map in history) {
        final int ts = (map['timestamp'] as num?)?.toInt() ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
        _messages.add(_Message(
          text: map['content'] ?? '',
          isMe: map['_isMe'] == true,
          timestamp: ts,
        ));
      }
    });
    // 保持在底部
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _addMessage(String text, bool isMe, int timestamp) {
    setState(() {
      _messages.add(_Message(text: text, isMe: isMe, timestamp: timestamp));
    });
    // 滚动到底部
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    if (_peerUid == null || _peerUid!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("聊天服务未连接")));
      return;
    }

    try {
      final int ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      // 构造 JSON 消息
      final Map<String, dynamic> jsonMsg = {
        "order_id": widget.orderId,
        "content": text,
        "type": "text",
        "timestamp": ts,
      };
      
      await RtmManager().sendMessageToPeer(_peerUid!, jsonEncode(jsonMsg));
      _addMessage(text, true, ts);
      _controller.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("发送失败: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("与 ${widget.otherUserName} 聊天"),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 1,
      ),
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final dt = DateTime.fromMillisecondsSinceEpoch(msg.timestamp * 1000);
                final timeStr = "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";

                return Align(
                  alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: msg.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: msg.isMe ? Colors.blue : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                        child: Text(
                          msg.text,
                          style: TextStyle(color: msg.isMe ? Colors.white : Colors.black87),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          timeStr,
                          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            color: Colors.white,
            child: SafeArea(
              top: false, // 底部栏不需要顶部安全区域，避免高度异常
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: "输入消息...",
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.blue),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Message {
  final String text;
  final bool isMe;
  final int timestamp;
  _Message({required this.text, required this.isMe, required this.timestamp});
}