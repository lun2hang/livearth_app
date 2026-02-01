import 'package:flutter/material.dart';
import 'package:dio/dio.dart'; // 导入 Dio 以处理异常
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'api/dio_client.dart';
import 'models/task.dart';
import 'models/supply.dart';
import 'models/order.dart';
import 'profile_screen.dart'; // 导入新的用户中心页面
import 'search_screen.dart'; // 导入搜索页面
import 'publish_task_screen.dart'; // 导入需求发布页
import 'publish_supply_screen.dart'; // 导入供给发布页
import 'task_detail_screen.dart'; // 导入需求详情页
import 'supply_detail_screen.dart'; // 导入供给详情页
import 'order_list_screen.dart'; // 导入订单列表页
import 'call_screen.dart'; // 导入通话页面

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
    
    final Map<String, dynamic> queryParams = {'is_consumer': isConsumer};

    // 如果是供给者模式，尝试获取并传递经纬度
    if (!isConsumer) {
      const storage = FlutterSecureStorage();
      final lat = await storage.read(key: 'latitude');
      final lng = await storage.read(key: 'longitude');
      if (lat != null && lng != null) {
        queryParams['user_lat'] = lat;
        queryParams['user_lng'] = lng;
      }
    }

    try {
      // 统一调用 /feed 接口，通过 query 参数区分角色
      final response = await dio.get(
        '/feed',
        queryParameters: queryParams,
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
      // 调用 /create 接口，is_consumer=true 代表发布需求
      final response = await dio.post(
        '/create',
        data: task.toJson(),
        queryParameters: {'is_consumer': true},
      );
      // 3. 获得返回值，并 print 出来
      print("API响应 (Task): ${response.data}");
    } catch (e) {
      print("API调用: 发布需求失败 -> $e");
    }
  }

  // 发布供给
  static Future<void> publishSupply(Supply supply) async {
    final dio = DioClient().dio;
    try {
      // 调用 /create 接口，is_consumer=false 代表发布供给
      final response = await dio.post(
        '/create',
        data: supply.toJson(),
        queryParameters: {'is_consumer': false},
      );
      // 3. 获得返回值，并 print 出来
      print("API响应 (Supply): ${response.data}");
    } catch (e) {
      print("API调用: 发布供给失败 -> $e");
    }
  }

  // 搜索功能
  static Future<List<dynamic>> search(String query, bool isConsumer) async {
    final dio = DioClient().dio;
    
    final Map<String, dynamic> queryParams = {
      'q': query,
      'is_consumer': isConsumer,
    };

    // 如果是供给者模式，尝试获取并传递经纬度
    if (!isConsumer) {
      const storage = FlutterSecureStorage();
      final lat = await storage.read(key: 'latitude');
      final lng = await storage.read(key: 'longitude');
      if (lat != null && lng != null) {
        queryParams['user_lat'] = lat;
        queryParams['user_lng'] = lng;
      }
    }

    try {
      final response = await dio.get(
        '/search',
        queryParameters: queryParams,
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

  // 获取当前用户的发布需求历史 (Task)
  static Future<List<Task>> fetchUserTasks() async {
    final dio = DioClient().dio;
    try {
      final response = await dio.get('/history/task');
      final List<dynamic> data = response.data;
      return data.map((json) => Task.fromJson(json)).toList();
    } catch (e) {
      print("API调用: 获取需求历史失败 -> $e");
      return [];
    }
  }

  // 获取当前用户的发布供给历史 (Supply)
  static Future<List<Supply>> fetchUserSupplies() async {
    final dio = DioClient().dio;
    try {
      // 假设后端有对应的 /history/supply 接口，如果只有 task 接口，请根据实际情况调整
      final response = await dio.get('/history/supply');
      final List<dynamic> data = response.data;
      return data.map((json) => Supply.fromJson(json)).toList();
    } catch (e) {
      print("API调用: 获取供给历史失败 -> $e");
      return [];
    }
  }

  // 接单 (供给者接受需求)
  static Future<bool> acceptTask(int taskId) async {
    final dio = DioClient().dio;
    try {
      // POST /orders/task/{task_id}/accept
      final response = await dio.post('/orders/task/$taskId/accept');
      print("API响应 (Accept Task): ${response.data}");
      return true;
    } catch (e) {
      print("API调用: 接单失败 -> $e");
      return false;
    }
  }

  // 预订 (消费者预订供给)
  static Future<bool> bookSupply(int supplyId) async {
    final dio = DioClient().dio;
    try {
      // POST /orders/supply/{supply_id}/book
      final response = await dio.post('/orders/supply/$supplyId/book');
      print("API响应 (Book Supply): ${response.data}");
      return true;
    } catch (e) {
      print("API调用: 预订失败 -> $e");
      return false;
    }
  }

  // 取消发布 (Task/Supply/Order)
  static Future<bool> cancelEntry(int id, String type) async {
    final dio = DioClient().dio;
    try {
      final response = await dio.post('/cancel', data: {'id': id, 'type': type});
      print("API响应 (Cancel): ${response.data}");
      return true;
    } catch (e) {
      print("API调用: 取消失败 -> $e");
      return false;
    }
  }

  // 获取当前用户的订单列表
  static Future<List<OrderWithDetails>> fetchUserOrders() async {
    final dio = DioClient().dio;
    try {
      final response = await dio.get('/orders');
      final List<dynamic> data = response.data;
      return data.map((json) => OrderWithDetails.fromJson(json)).toList();
    } catch (e) {
      print("API调用: 获取订单列表失败 -> $e");
      return [];
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
  OrderWithDetails? _pendingOrder; // 最早的待处理订单

  @override
  void initState() {
    super.initState();
    // 启动时检查 Token 有效性 (如果过期，会自动清除本地存储)
    DioClient().checkTokenValidity();
    _initLocation(); // 启动时自动获取位置
    _loadFeedData(); // 初始化加载数据
  }

  // --- 逻辑方法 ---

  // 0. 自动获取位置
  Future<void> _initLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      // 获取经纬度
      Position position = await Geolocator.getCurrentPosition();
      
      const storage = FlutterSecureStorage();
      await storage.write(key: 'latitude', value: position.latitude.toString());
      await storage.write(key: 'longitude', value: position.longitude.toString());

      // 逆地理编码 (保持与 ProfileScreen 逻辑一致，以便个人中心能直接读取)
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final province = place.administrativeArea ?? '';
          final city = place.locality ?? '';
          final district = place.subLocality ?? '';
          
          List<String> parts = [];
          if (province.isNotEmpty) parts.add(province);
          if (city.isNotEmpty && city != province) parts.add(city);
          if (district.isNotEmpty) parts.add(district);
          
          String locationText = parts.isNotEmpty ? parts.join(' ') : (place.country ?? "未知位置");
          await storage.write(key: 'location', value: locationText);
        }
      } catch (_) {}

      // 获取位置后刷新列表，以便按距离排序
      _loadFeedData();
    } catch (e) {
      print("自动定位失败: $e");
    }
  }

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
    
    // 并行请求：获取Feed流 + 检查待处理订单
    final results = await Future.wait([
      MockAPI.fetchFeedItems(isConsumer: _isConsumerMode),
      _checkPendingOrders(),
    ]);
    
    final items = results[0] as List<dynamic>;
    
    if (mounted) {
      setState(() {
        _feedItems = items;
        _isLoading = false;
      });
    }
  }

  // 新增：检查是否有状态为 created 的订单
  Future<void> _checkPendingOrders() async {
    // 简单检查是否登录
    const storage = FlutterSecureStorage();
    if (await storage.read(key: 'access_token') == null) {
      if (mounted) setState(() => _pendingOrder = null);
      return;
    }

    final orders = await MockAPI.fetchUserOrders();
    // 筛选 status == 'created'
    final pending = orders.where((o) {
      if (o.status != 'created') return false;
      
      // 增加本地超时校验：如果当前时间超过开始时间，视为超时，不显示提醒
      if (o.startTime != null) {
        try {
          String timeStr = o.startTime!;
          if (!timeStr.endsWith('Z')) timeStr += 'Z'; // 强制视为 UTC
          final startTime = DateTime.parse(timeStr);
          if (DateTime.now().toUtc().isAfter(startTime)) { // 使用 UTC 进行比较
            return false;
          }
        } catch (_) {}
      }
      return true;
    }).toList();
    
    if (pending.isNotEmpty) {
      // 按开始时间排序，取最早的一条 (如果 startTime 为空则回退到 createdAt)
      pending.sort((a, b) {
        final timeA = a.startTime ?? a.createdAt;
        final timeB = b.startTime ?? b.createdAt;
        return timeA.compareTo(timeB);
      });
      if (mounted) setState(() => _pendingOrder = pending.first);
    } else {
      if (mounted && _pendingOrder != null) setState(() => _pendingOrder = null);
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
  Future<void> _onAddTap() async {
    // 1. 检查是否已登录
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    
    if (token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先登录以发布内容')),
        );
        _onProfileTap(); // 跳转到个人中心进行登录
      }
      return;
    }

    if (_isConsumerMode) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PublishTaskScreen()),
      ).then((_) => _loadFeedData()); // 发布后刷新列表
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PublishSupplyScreen()),
      ).then((_) => _loadFeedData());
    }
  }

  // 5. 点击个人主页
  void _onProfileTap() {
    print("UI交互: 跳转到个人主页");
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfileScreen()),
    ).then((_) => _checkPendingOrders()); // 从个人中心(可能操作订单)返回时刷新提醒
  }

  // 新增：本地更新列表项状态，避免重新加载网络请求
  void _handleItemChange(int id, String newStatus) {
    final index = _feedItems.indexWhere((e) => (e is Supply && e.id == id) || (e is Task && e.id == id));
    if (index != -1) {
      setState(() {
        final item = _feedItems[index];
        if (item is Supply) {
          _feedItems[index] = Supply(
            id: item.id,
            userId: item.userId,
            title: item.title,
            description: item.description,
            lat: item.lat,
            lng: item.lng,
            rating: item.rating,
            price: item.price,
            status: newStatus,
            createdAt: item.createdAt,
            validFrom: item.validFrom,
            validTo: item.validTo,
          );
        } else if (item is Task) {
          _feedItems[index] = Task(
            id: item.id,
            userId: item.userId,
            title: item.title,
            description: item.description,
            lat: item.lat,
            lng: item.lng,
            budget: item.budget,
            status: newStatus,
            createdAt: item.createdAt,
            validFrom: item.validFrom,
            validTo: item.validTo,
          );
        }
      });
    }
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

            // [区域 2.5] 待处理订单提醒条 (固定在底部栏上方)
            if (_pendingOrder != null) _buildPendingOrderBar(),
          ],
        ),
      ),
      
      // [区域 3] 底部横条 (自定义 BottomAppBar)
      bottomNavigationBar: _buildBottomBar(primaryColor, roleText),
    );
  }

  // 组件：待处理订单提醒条
  Widget _buildPendingOrderBar() {
    // 格式化时间显示
    String timeDisplay = "未知时间";
    if (_pendingOrder != null) {
      var rawTime = _pendingOrder!.startTime ?? _pendingOrder!.createdAt;
      if (!rawTime.endsWith('Z')) rawTime += 'Z'; // 强制视为 UTC
      try {
        final localTime = DateTime.parse(rawTime).toLocal(); // 转为本地时间
        // 格式化: MM-dd HH:mm
        timeDisplay = "${localTime.month.toString().padLeft(2, '0')}-${localTime.day.toString().padLeft(2, '0')} ${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}";
      } catch (_) {
        timeDisplay = rawTime;
      }
    }

    return Container(
      width: double.infinity,
      color: Colors.green.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.video_call, color: Colors.green),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "您有一个即将开始的订单",
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 14),
                ),
                Text(
                  "开始时间: $timeDisplay",
                  style: TextStyle(fontSize: 12, color: Colors.green[700]),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.call, color: Colors.green),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => CallScreen(orderId: _pendingOrder!.id)),
                  );
                },
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const OrderListScreen()),
                  ).then((_) => _checkPendingOrders()); // 从订单列表返回时刷新
                },
                child: const Text("查看", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
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

          // -------------------------------------------------------
          // 针对 Supply (供给) 的新样式
          // -------------------------------------------------------
          if (item is Supply) {
            return GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => SupplyDetailScreen(supply: item))).then((result) {
                  if (result == true) {
                    _handleItemChange(item.id, 'canceled');
                  } else {
                    _loadFeedData();
                  }
                });
              },
              child: Container(
                height: 135, // 增加高度以容纳4行信息
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
                      width: 110,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.videocam, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 12),
                    // 右侧：信息内容
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly, // 均匀分布三行
                        children: [
                          // 第一行：【提供】标题
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          // 第二行：描述 (尝试获取 description，若无则显示默认文案)
                          Text(
                            (item as dynamic).toJson()['description'] ?? "暂无详细描述信息...",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          // 第三行：发布者昵称
                          Text(
                            "供给者: ${item.nickname ?? '匿名用户'}",
                            style: TextStyle(fontSize: 12, color: Colors.blueGrey[600]),
                          ),
                          // 第三行：图标展示价格，评分，距离，时间
                          Row(
                            children: [
                              // 价格
                              Icon(Icons.attach_money, size: 12, color: Colors.orange),
                              Text("${(item as dynamic).toJson()['price'] ?? '-'}", style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              // 评分
                              const Icon(Icons.star, size: 12, color: Colors.amber),
                              Text("${item.rating}", style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                              const SizedBox(width: 8),
                              // 距离
                              Icon(Icons.location_on, size: 12, color: Colors.grey[400]),
                              Text("500m", style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                              const Spacer(),
                              // 时间
                              Text("刚刚", style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // -------------------------------------------------------
          // 针对 Task (需求) 的新样式
          // -------------------------------------------------------
          if (item is Task) {
            return GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => TaskDetailScreen(task: item))).then((result) {
                  if (result == true) {
                    _handleItemChange(item.id, 'canceled');
                  } else {
                    _loadFeedData();
                  }
                });
              },
              child: Container(
                height: 135, // 增加高度以容纳4行信息
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
                      width: 110,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.videocam, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 12),
                    // 右侧：信息内容
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // 第一行：标题 (加粗)
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          // 第二行：详情 (描述)
                          Text(
                            (item as dynamic).toJson()['description'] ?? "暂无详细需求描述...",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          // 第三行：发布者昵称
                          Text(
                            "需求者: ${item.nickname ?? '匿名用户'}",
                            style: TextStyle(fontSize: 12, color: Colors.blueGrey[600]),
                          ),
                          // 第三行：价格 距离 时间
                          Row(
                            children: [
                              // 价格 (预算)
                              Icon(Icons.attach_money, size: 12, color: Colors.red),
                              Text("${item.budget}", style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              // 距离
                              Icon(Icons.location_on, size: 12, color: Colors.grey[400]),
                              Text("500m", style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                              const Spacer(),
                              // 时间
                              Text("刚刚", style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // -------------------------------------------------------
          // 其他未知类型的兜底样式
          // -------------------------------------------------------
          String displayTitle = "";
          displayTitle = item.toString();

          // 模拟卡片高度，确保一屏展示 5-6 条
          return GestureDetector(
            onTap: () {
              // 未知类型点击暂无操作
            },
            child: Container(
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
            ),
          );
        },
      ),
    );
  }

  // 组件：底部导航栏
  Widget _buildBottomBar(Color primaryColor, String roleText) {
    return BottomAppBar(
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
            
            // 中间的加号按钮 (不再悬浮，而是平级排列)
            GestureDetector(
              onTap: _onAddTap,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 30),
              ),
            ),

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