import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

// ---------------------------------------------------------------------------
// 1. Mock API 接口层 (占位符)
// 这里定义了后端交互的契约，目前只打印日志，后续替换为 FastAPI 调用
// ---------------------------------------------------------------------------
class MockAPI {
  // 模拟：获取任务列表 (供需双方看到的数据不同)
  static Future<List<String>> fetchFeedItems({required bool isConsumer}) async {
    // 模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 500));
    if (isConsumer) {
      // 消费者模式下：看到的是“供给列表” (谁能帮我看)
      return List.generate(10, (index) => "供给 #$index: 东京铁塔现场直播 - 距离 2km");
    } else {
      // 供给者模式下：看到的是“需求列表” (谁想看什么)
      return List.generate(10, (index) => "需求 #$index: 想看涩谷十字路口人流 - 预算 \$10");
    }
  }

  // 模拟：发布功能
  static void publishTask(String description) {
    print("API调用: 发布需求任务 -> $description");
  }

  static void publishSupply(String description) {
    print("API调用: 发布供给服务 -> $description");
  }

  // 模拟：搜索功能
  static void search(String query, bool searchSupplyLibrary) {
    print("API调用: 搜索 -> 关键词: $query, 搜索库: ${searchSupplyLibrary ? '供给库' : '任务库'}");
  }
}

// ---------------------------------------------------------------------------
// 2. 应用程序入口
// ---------------------------------------------------------------------------
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Livearth',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        // 简单的样式调整
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      home: const MainScreen(),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. 主屏幕 (包含所有交互逻辑)
// ---------------------------------------------------------------------------
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // --- 核心状态 ---
  // true = 消费者 (发布需求，看供给流)
  // false = 供给者 (发布供给，看需求流)
  bool _isConsumerMode = true; 
  
  // 信息流数据
  List<String> _feedItems = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadFeedData(); // 初始化加载数据
  }

  // --- 逻辑方法 ---

  // 1. 切换角色
  void _toggleRole() {
    setState(() {
      _isConsumerMode = !_isConsumerMode;
      // 切换角色后，清空并重新加载对应的信息流
      _feedItems.clear();
      _loadFeedData();
    });
  }

  // 2. 加载数据 (调用 Mock API)
  Future<void> _loadFeedData() async {
    setState(() => _isLoading = true);
    final items = await MockAPI.fetchFeedItems(isConsumer: _isConsumerMode);
    if (mounted) {
      setState(() {
        _feedItems = items;
        _isLoading = false;
      });
    }
  }

  // 3. 点击搜索
  void _onSearchTap() {
    print("UI交互: 跳转到搜索页");
    // 这里未来会使用 Navigator.push 跳转到搜索页面
    // 传递参数: targetLibrary = _isConsumerMode ? '供给库' : '任务库'
    MockAPI.search("测试搜索", _isConsumerMode);
  }

  // 4. 点击加号 (发布)
  void _onAddTap() {
    if (_isConsumerMode) {
      print("UI交互: 弹出'发布需求'表单");
      MockAPI.publishTask("新发布的需求");
    } else {
      print("UI交互: 弹出'发布供给'表单");
      MockAPI.publishSupply("新发布的供给");
    }
  }

  // 5. 点击个人主页
  void _onProfileTap() {
    print("UI交互: 跳转到个人主页");
    // Navigator.push(context, ...)
  }

  // --- UI 构建 ---

  @override
  Widget build(BuildContext context) {
    // 根据角色定义颜色，方便调试区分
    final primaryColor = _isConsumerMode ? Colors.blue : Colors.orange;
    final roleText = _isConsumerMode ? "我是消费者 (看世界)" : "我是供给者 (直播现场)";

    return Scaffold(
      // 使用 SafeArea 确保在 iPhone 刘海屏上显示正常
      body: SafeArea(
        child: Column(
          children: [
            // [区域 1] 顶部搜索框
            _buildSearchBar(primaryColor),

            // [区域 2] 中间信息流 (类似今日头条)
            Expanded(
              child: _buildFeedList(),
            ),
          ],
        ),
      ),
      
      // [区域 3] 底部横条 (自定义 BottomAppBar)
      bottomNavigationBar: _buildBottomBar(primaryColor, roleText),
      
      // 中间的加号按钮 (悬浮在 BottomBar 之上)
      floatingActionButton: FloatingActionButton(
        onPressed: _onAddTap,
        backgroundColor: primaryColor,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  // 组件：顶部搜索框
  Widget _buildSearchBar(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Colors.white,
      child: GestureDetector(
        onTap: _onSearchTap,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Icon(Icons.search, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                // 搜索提示词随角色变化
                _isConsumerMode ? "搜索感兴趣的地点或供给..." : "搜索附近的任务需求...",
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 组件：中间信息流列表
  Widget _buildFeedList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadFeedData,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 80), // 底部留白给 FAB
        itemCount: _feedItems.length,
        itemBuilder: (context, index) {
          // 模拟卡片高度，确保一屏展示 5-6 条
          return Container(
            height: 110, // 固定高度模拟
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Row(
              children: [
                // 左侧：图片/视频占位符
                Container(
                  width: 120,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.videocam, color: Colors.white),
                ),
                const SizedBox(width: 12),
                // 右侧：信息内容
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _feedItems[index],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text("500m", style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                          const Spacer(),
                          Text(
                            "刚刚",
                            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 组件：底部导航栏
  Widget _buildBottomBar(Color primaryColor, String roleText) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(), // 制作中间的凹陷
      notchMargin: 8.0, // 凹陷与按钮的间距
      color: Colors.white,
      child: SizedBox(
        height: 60.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 左下角：角色切换按钮
            InkWell(
              onTap: _toggleRole,
              borderRadius: BorderRadius.circular(30),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isConsumerMode ? Icons.remove_red_eye : Icons.video_camera_front,
                      color: primaryColor,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isConsumerMode ? "我要看" : "我要播",
                      style: TextStyle(
                        fontSize: 10, 
                        color: primaryColor,
                        fontWeight: FontWeight.bold
                      ),
                    )
                  ],
                ),
              ),
            ),
            
            // 中间留白 (给 FloatingActionButton)
            const SizedBox(width: 40),

            // 右下角：个人主页按钮
            InkWell(
              onTap: _onProfileTap,
              borderRadius: BorderRadius.circular(30),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.person_outline, color: Colors.grey),
                    const SizedBox(height: 4),
                    const Text(
                      "我的",
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}