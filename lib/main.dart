import 'package:flutter/material.dart';
import 'api/dio_client.dart';
import 'models/task.dart';
import 'models/supply.dart';
import 'profile_screen.dart'; // 导入新的用户中心页面
import 'search_screen.dart'; // 导入搜索页面
import 'publish_task_screen.dart'; // 导入需求发布页
import 'publish_supply_screen.dart'; // 导入供给发布页

void main() {
  runApp(const MyApp());
}

// ---------------------------------------------------------------------------
// 1. Mock API 接口层 (占位符)
// 已替换为真实网络请求 (FastAPI)
// ---------------------------------------------------------------------------
class MockAPI {
  // 获取任务/供给列表
  static Future<List<dynamic>> fetchFeedItems({required bool isConsumer}) async {
    final dio = DioClient().dio;
    try {
      // 统一调用 /feed 接口，通过 query 参数区分角色
      final response = await dio.get(
        '/feed',
        queryParameters: {'is_consumer': isConsumer},
      );
      final List<dynamic> data = response.data;

      if (isConsumer) {
        // 消费者模式下：看到的是“供给列表” (Supply)
        return data
            .map<dynamic>((json) => Supply.fromJson(json))
            .toList();
      } else {
        // 供给者模式下：看到的是“需求列表” (Task)
        return data
            .map<dynamic>((json) => Task.fromJson(json))
            .toList();
      }
    } catch (e) {
      print("API 请求失败: $e");
      return <dynamic>["加载失败，请检查网络连接"];
    }
  }

  // 发布需求
  static Future<void> publishTask(Task task) async {
    final dio = DioClient().dio;
    try {
      await dio.post('/tasks', data: task.toJson());
      print("API调用: 发布需求成功 -> ${task.title}");
    } catch (e) {
      print("API调用: 发布需求失败 -> $e");
    }
  }

  // 发布供给
  static Future<void> publishSupply(Supply supply) async {
    final dio = DioClient().dio;
    try {
      await dio.post('/supplies', data: supply.toJson());
      print("API调用: 发布供给成功 -> ${supply.title}");
    } catch (e) {
      print("API调用: 发布供给失败 -> $e");
    }
  }

  // 搜索功能
  static Future<List<dynamic>> search(String query, bool isConsumer) async {
    final dio = DioClient().dio;
    try {
      final response = await dio.get(
        '/search',
        queryParameters: {
          'q': query,
          'is_consumer': isConsumer,
        },
      );
      // 后端返回结构: {"query": "...", "target": "...", "results": [...]}
      final List<dynamic> data = response.data['results'];

      if (isConsumer) {
        return data.map<dynamic>((json) => Supply.fromJson(json)).toList();
      } else {
        return data.map<dynamic>((json) => Task.fromJson(json)).toList();
      }
    } catch (e) {
      print("API调用: 搜索失败 -> $e");
      return <dynamic>[];
    }
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
  List<dynamic> _feedItems = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadFeedData(); // 初始化加载数据
  }

  // --- 逻辑方法 ---

  // 1. 切换角色
  void _toggleRole() {
    if (_isLoading) return; // 防止在加载时重复切换
    setState(() {
      _isConsumerMode = !_isConsumerMode;
    });
    print("UI交互: 切换角色 -> ${_isConsumerMode ? '消费者' : '供给者'}");
    // 状态改变后，触发数据重新加载
    _loadFeedData();
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchScreen(isConsumerMode: _isConsumerMode),
      ),
    );
  }

  // 4. 点击加号 (发布)
  void _onAddTap() {
    if (_isConsumerMode) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PublishTaskScreen()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PublishSupplyScreen()),
      );
    }
  }

  // 5. 点击个人主页
  void _onProfileTap() {
    print("UI交互: 跳转到个人主页");
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfileScreen()),
    );
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
          final item = _feedItems[index];
          String displayTitle = "";

          if (item is Task) {
            displayTitle = "需求 #${item.id}: ${item.title} - 预算 \$${item.budget}";
          } else if (item is Supply) {
            displayTitle = "供给 #${item.id}: ${item.title} - 评分 ${item.rating}";
          } else {
            displayTitle = item.toString();
          }

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
                        displayTitle,
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