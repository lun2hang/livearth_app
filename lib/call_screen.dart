import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'api/dio_client.dart';

class CallScreen extends StatefulWidget {
  final int orderId;
  final bool isProvider;

  const CallScreen({super.key, required this.orderId, this.isProvider = false});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  int? _remoteUid; // 远端用户的数字 ID (Agora 自动分配)
  bool _localUserJoined = false;
  late RtcEngine _engine;
  bool _isReady = false;
  String? _channelName;

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    // 1. 请求权限
    await [Permission.microphone, Permission.camera].request();

    // 2. 获取 Token
    final data = await DioClient().getRtcToken(widget.orderId);
    if (data == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("无法获取通话凭证")));
        Navigator.pop(context);
      }
      return;
    }

    final String appId = data['app_id'];
    final String token = data['token'];
    final String channelName = data['channel_name'];
    final String userAccount = data['uid']; // 后端返回的是 String UID (UUID)

    setState(() {
      _channelName = channelName;
    });

    // 3. 初始化引擎
    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(
      appId: appId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    // 4. 注册事件回调
    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onError: (ErrorCodeType err, String msg) {
          debugPrint("❌ [Agora Error] $err: $msg");
        },
        onConnectionStateChanged: (RtcConnection connection, ConnectionStateType state, ConnectionChangedReasonType reason) {
          debugPrint("📡 [Agora Connection] State: ${state.name}, Reason: ${reason.name}");
        },
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint("✅ [Agora] Local user joined: ${connection.localUid}");
          if (mounted) {
            setState(() {
              _localUserJoined = true;
            });
          }
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint("👤 [Agora] Remote user joined: $remoteUid");
          if (mounted) {
            setState(() {
              _remoteUid = remoteUid;
            });
          }
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          debugPrint("👋 [Agora] Remote user offline: $remoteUid");
          if (mounted) {
            setState(() {
              _remoteUid = null;
            });
          }
        },
        onUserInfoUpdated: (int uid, UserInfo info) {
          debugPrint("🔁 [Agora] User Info Updated: Int($uid) -> String(${info.userAccount})");
        },
      ),
    );

    // 5. 开启视频并加入频道
    await _engine.enableVideo();
    
    if (widget.isProvider) {
      await _engine.startPreview();
      // 供给者默认使用后置摄像头
      await _engine.switchCamera();
    } else {
      // 消费者：开启麦克风，关闭摄像头
      await _engine.muteLocalVideoStream(true);
    }

    // 使用 String UID 加入 (因为后端使用的是 String UID 生成 Token)
    // ⚠️ 关键点: 必须使用 joinChannelWithUserAccount 而不是 joinChannel
    // 否则 Token 校验会失败 (String UID vs Int UID)
    await _engine.joinChannelWithUserAccount(
      token: token,
      channelId: channelName,
      userAccount: userAccount,
    );
    
    // 通知后端用户已加入视频通话
    try {
      await DioClient().dio.post('/orders/${widget.orderId}/live-join');
      debugPrint("✅ [API] 调用 live-join 成功");
    } catch (e) {
      debugPrint("❌ [API] 调用 live-join 失败: $e");
    }

    if (mounted) {
      setState(() {
        _isReady = true;
      });
    }
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  Future<void> _dispose() async {
    // 通知后端用户退出视频通话
    try {
      await DioClient().dio.post('/orders/${widget.orderId}/live-leave');
      debugPrint("✅ [API] 调用 live-leave 成功");
    } catch (e) {
      debugPrint("❌ [API] 调用 live-leave 失败: $e");
    }

    await _engine.leaveChannel();
    await _engine.release();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('视频通话'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 远端视频 (全屏)
          Center(
            child: _remoteVideo(),
          ),
          // 本地视频 (左上角悬浮窗)
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: 120,
                height: 160,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    color: Colors.grey[800],
                    child: _localUserJoined
                        ? AgoraVideoView(
                            controller: VideoViewController(
                              rtcEngine: _engine,
                              canvas: const VideoCanvas(uid: 0), // 0 表示本地
                            ),
                          )
                        : const Center(child: CircularProgressIndicator(color: Colors.white)),
                  ),
                ),
              ),
            ),
          ),
          // 挂断按钮
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40.0),
              child: FloatingActionButton(
                onPressed: () => Navigator.pop(context),
                backgroundColor: Colors.red,
                child: const Icon(Icons.call_end, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _remoteVideo() {
    if (_remoteUid != null && _channelName != null) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _engine,
          canvas: VideoCanvas(uid: _remoteUid),
          connection: RtcConnection(channelId: _channelName!),
        ),
      );
    } else {
      return const Text(
        '等待对方加入...',
        style: TextStyle(color: Colors.white70, fontSize: 18),
      );
    }
  }
}