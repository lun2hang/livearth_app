import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agora_rtm/agora_rtm.dart';
import 'api/dio_client.dart';

class ChatScreen extends StatefulWidget {
  final int orderId;
  final String currentUserId;
  final String otherUserName;

  const ChatScreen({
    super.key,
    required this.orderId,
    required this.currentUserId,
    required this.otherUserName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  AgoraRtmClient? _client;
  AgoraRtmChannel? _channel;
  final List<_Message> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLogin = false;
  bool _isJoined = false;

  @override
  void initState() {
    super.initState();
    _initAgoraRtm();
  }

  @override
  void dispose() {
    _dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _dispose() async {
    if (_isJoined && _channel != null) {
      await _channel!.leave();
    }
    if (_isLogin && _client != null) {
      await _client!.logout();
    }
    await _channel?.release();
    await _client?.release();
  }

  Future<void> _initAgoraRtm() async {
    try {
      // 1. 获取 Token (包含 RTM Token)
      final data = await DioClient().getAgoraToken(widget.orderId);
      if (data == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("无法获取聊天凭证")));
          Navigator.pop(context);
        }
        return;
      }

      // 使用 ?? "" 防止 null 变成 "null" 字符串
      final String appId = (data['app_id'] ?? "").toString().trim();
      final String rtmToken = (data['rtm_token'] ?? "").toString().trim();
      final String channelName = (data['channel_name'] ?? "").toString().trim();
      // ⚠️ 针对 RTM 登录去除 UID 中的减号 (需确保后端生成 Token 时也同步去除了减号)
      final String uid = (data['uid'] ?? "").toString().trim().replaceAll('-', '');
      final String rtcToken = (data['token'] ?? "").toString().trim();

      if (appId.isEmpty || rtmToken.isEmpty || uid.isEmpty) {
        debugPrint("❌ RTM 参数错误: AppID=$appId, TokenLen=${rtmToken.length}, UID=$uid");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("聊天参数不完整")));
        }
        return;
      }

      // 2. 初始化 Client
      _client = await AgoraRtmClient.createInstance(appId);
      // 设置 RTM 日志等级 (0: OFF, 15: INFO, 14: WARN, 12: ERROR)
      // 建议开发环境用 15，生产环境用 14 或 12 以减少日志噪音
      await _client?.setParameters('{"rtm.log_filter": 15}');
      
      // 3. 登录 RTM 系统
      debugPrint("=== RTM Login Debug ===");
      debugPrint("AppID: '$appId'");
      debugPrint("UID: '$uid'");
      debugPrint("RTM Token: '$rtmToken'");
      if (rtmToken.isNotEmpty && rtmToken == rtcToken) {
        debugPrint("⚠️ 警告: RTM Token 与 RTC Token 完全一致，这通常是错误的！");
      }
      await _client?.login(rtmToken, uid);
      setState(() => _isLogin = true);

      // 4. 创建并加入频道 (与 RTC 频道同名)
      _channel = await _client?.createChannel(channelName);
      
      // 监听频道消息
      _channel?.onMessageReceived = (AgoraRtmMessage message, AgoraRtmMember member) {
        // 过滤掉自己发的消息 (虽然 RTM 默认不推给自己，但为了保险)
        if (member.userId != uid) {
          _addMessage(message.text, false);
        }
      };
      
      await _channel?.join();
      setState(() => _isJoined = true);
      
      debugPrint("✅ RTM 加入成功: $channelName");

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

  void _addMessage(String text, bool isMe) {
    setState(() {
      _messages.add(_Message(text: text, isMe: isMe));
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

    if (!_isLogin || !_isJoined || _channel == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("未连接到聊天室")));
      return;
    }

    try {
      final message = AgoraRtmMessage.fromText(text);
      await _channel!.sendMessage(message);
      _addMessage(text, true);
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
                return Align(
                  alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
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
  _Message({required this.text, required this.isMe});
}