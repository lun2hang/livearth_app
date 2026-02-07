import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agora_rtm/agora_rtm.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api/dio_client.dart';

/// 全局 RTM 管理器 (单例)
class RtmManager {
  static final RtmManager _instance = RtmManager._internal();
  factory RtmManager() => _instance;
  RtmManager._internal();

  AgoraRtmClient? _client;
  // UI 消息回调: (AgoraRtmMessage message, String peerId)
  Function(AgoraRtmMessage, String)? onMessageReceived;
  // 消息缓存: peerId -> List<MessageJson> (包含 _isMe 字段)
  final Map<String, List<Map<String, dynamic>>> _messageCache = {};
  
  // 本地存储
  final _storage = const FlutterSecureStorage();
  String? _currentUid;

  // 未读消息计数: orderId -> count
  final ValueNotifier<Map<String, int>> unreadCountsNotifier = ValueNotifier({});
  String? _activeOrderId; // 当前处于活跃状态的聊天订单ID

  bool get isLogin => _client != null;

  /// 初始化并登录 RTM
  Future<void> init(String appId, String token, String uid) async {
    if (_client != null) return; // 已连接则跳过

    _currentUid = uid;
    await _loadCache(); // 优先加载本地缓存
    await _loadUnreadCache(); // 加载未读计数

    debugPrint("🔄 [RTM] 开始全局初始化: UID=$uid");
    try {
      _client = await AgoraRtmClient.createInstance(appId);
      // 设置日志等级
      await _client?.setParameters('{"rtm.log_filter": 15}');
      
      // 设置全局消息监听
      _client?.onMessageReceived = (AgoraRtmMessage message, String peerId) async {
        debugPrint("📩 [RTM] 收到消息 from $peerId: ${message.text}");
        
        // 1. 存入缓存
        try {
          final Map<String, dynamic> map = jsonDecode(message.text);
          map['_isMe'] = false; // 标记为接收
          if (!_messageCache.containsKey(peerId)) {
            _messageCache[peerId] = [];
          }
          _messageCache[peerId]!.add(map);
          await _saveCache(); // 持久化保存

          // 2. 更新未读计数
          final String orderId = map['order_id'].toString();
          // 如果当前不在该订单的聊天窗口，则增加未读计数
          if (_activeOrderId != orderId) {
            final current = Map<String, int>.from(unreadCountsNotifier.value);
            current[orderId] = (current[orderId] ?? 0) + 1;
            unreadCountsNotifier.value = current;
            await _saveUnreadCache();
          }
        } catch (e) {
          debugPrint("❌ [RTM] 缓存接收消息失败: $e");
        }

        // 转发给当前的 UI 监听器 (如果有)
        if (onMessageReceived != null) {
          onMessageReceived!(message, peerId);
        }
      };

      await _client?.login(token, uid);
      debugPrint("✅ [RTM] 全局登录成功");
    } catch (e) {
      debugPrint("❌ [RTM] 全局登录失败: $e");
      _client = null;
    }
  }

  /// 发送 P2P 消息
  Future<void> sendMessageToPeer(String peerId, String text) async {
    if (_client == null) throw Exception("RTM 服务未连接");
    
    final message = AgoraRtmMessage.fromText(text);
    // 参数3: enableOfflineMessaging = true (开启离线消息)
    // 参数4: enableHistoricalMessaging = false
    await _client!.sendMessageToPeer(peerId, message, true, false);

    // 1. 发送成功后，存入缓存
    try {
      final Map<String, dynamic> map = jsonDecode(text);
      map['_isMe'] = true; // 标记为发送
      if (!_messageCache.containsKey(peerId)) {
        _messageCache[peerId] = [];
      }
      _messageCache[peerId]!.add(map);
      await _saveCache(); // 持久化保存
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

  /// 从本地存储加载缓存
  Future<void> _loadCache() async {
    if (_currentUid == null) return;
    try {
      final jsonStr = await _storage.read(key: 'rtm_cache_$_currentUid');
      if (jsonStr != null) {
        final Map<String, dynamic> decoded = jsonDecode(jsonStr);
        _messageCache.clear();
        decoded.forEach((key, value) {
          _messageCache[key] = List<Map<String, dynamic>>.from(
            (value as List).map((item) => Map<String, dynamic>.from(item))
          );
        });
      }
    } catch (e) {
      debugPrint("❌ [RTM] 加载本地缓存失败: $e");
    }
  }

  /// 保存缓存到本地
  Future<void> _saveCache() async {
    if (_currentUid == null) return;
    try {
      await _storage.write(key: 'rtm_cache_$_currentUid', value: jsonEncode(_messageCache));
    } catch (e) {
      debugPrint("❌ [RTM] 保存本地缓存失败: $e");
    }
  }

  /// 进入聊天窗口 (清除未读)
  void enterChat(String orderId) {
    _activeOrderId = orderId;
    _clearUnread(orderId);
  }

  /// 离开聊天窗口
  void leaveChat() {
    _activeOrderId = null;
  }

  Future<void> _clearUnread(String orderId) async {
    final current = Map<String, int>.from(unreadCountsNotifier.value);
    if (current.containsKey(orderId)) {
      current.remove(orderId);
      unreadCountsNotifier.value = current;
      await _saveUnreadCache();
    }
  }

  Future<void> _loadUnreadCache() async {
    if (_currentUid == null) return;
    try {
      final str = await _storage.read(key: 'rtm_unread_$_currentUid');
      if (str != null) {
        final Map<String, dynamic> decoded = jsonDecode(str);
        unreadCountsNotifier.value = decoded.map((k, v) => MapEntry(k, v as int));
      }
    } catch (e) {
      debugPrint("❌ [RTM] 加载未读计数失败: $e");
    }
  }

  Future<void> _saveUnreadCache() async {
    if (_currentUid == null) return;
    try {
      await _storage.write(key: 'rtm_unread_$_currentUid', value: jsonEncode(unreadCountsNotifier.value));
    } catch (e) {
      debugPrint("❌ [RTM] 保存未读计数失败: $e");
    }
  }

  /// 登出 (通常在切换账号时调用)
  Future<void> logout() async {
    try {
      await _client?.logout();
      await _client?.release();
      _client = null;
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
    RtmManager().leaveChat(); // 标记离开
    // 移除监听，但不要断开连接！
    RtmManager().onMessageReceived = null;
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initAgoraRtm() async {
    try {
      // 1. 设置 peerUid (直接从 widget 参数获取，并去除 UUID 中的减号以匹配 RTM 格式)
      _peerUid = widget.otherUserId.replaceAll('-', '');

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
          final String uid = (rtmData['uid'] ?? "").toString().trim().replaceAll('-', '');
          
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
      RtmManager().onMessageReceived = (AgoraRtmMessage message, String peerId) {
        // 过滤：只处理当前聊天对象的消息
        if (peerId == _peerUid) {
          if (mounted) {
            try {
              final Map<String, dynamic> map = jsonDecode(message.text);
              // 校验 order_id
              if (map['order_id'].toString() == widget.orderId.toString()) {
                final int ts = (map['timestamp'] as num?)?.toInt() ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
                _addMessage(map['content'] ?? '', false, ts);
              }
            } catch (e) {
              _addMessage(message.text, false, DateTime.now().millisecondsSinceEpoch ~/ 1000);
            }
          }
        }
      };

    } on MissingPluginException {
      debugPrint("❌ RTM 插件未加载: 请停止应用并重新编译运行 (Hot Restart 无法加载新插件)");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("请完全重启应用以加载新插件")));
      }
    } on AgoraRtmClientException catch (e) {
      debugPrint("❌ RTM Client 异常: Code=${e.code}, Reason=${e.reason}");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("聊天登录失败: ${e.code}")));
      }
    } catch (e) {
      debugPrint("❌ RTM 初始化失败: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("聊天服务连接失败: $e")));
      }
    }
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

    if (!RtmManager().isLogin || _peerUid == null || _peerUid!.isEmpty) {
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
    } on AgoraRtmClientException catch (e) {
      String msg = "发送失败: ${e.code}";
      if (e.code == 3) {
        msg = "对方不在线 (请在Agora控制台开启历史/离线消息)";
      }
      debugPrint("❌ RTM Send Error: Code=${e.code}, Reason=${e.reason}");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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