import 'package:flutter/material.dart';
import 'main.dart';
import 'models/task.dart';
import 'models/supply.dart';

class SearchScreen extends StatefulWidget {
  final bool isConsumerMode;

  const SearchScreen({super.key, required this.isConsumerMode});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _hasText = false;
  List<dynamic> _searchResults = [];
  bool _hasSearched = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // 监听输入框变化，实时更新按钮状态
    _controller.addListener(() {
      setState(() {
        _hasText = _controller.text.isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onSearch() async {
    // 使用 _hasText 状态判断，确保与右上角按钮的逻辑完全一致
    if (_hasText) {
      // [需求 1] 点击搜索后隐藏键盘
      FocusScope.of(context).unfocus();

      setState(() {
        _isLoading = true;
        _hasSearched = true;
        _searchResults = [];
      });

      final results = await MockAPI.search(_controller.text, widget.isConsumerMode);

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 1,
        // [需求 2] 搜索框左侧有返回箭头，点击可以返回主界面
        // AppBar 默认会自动添加返回按钮，但这里我们显式定义以确保样式统一
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        // [需求 1] 光标进入搜索框 (TextField)
        title: TextField(
          controller: _controller,
          // [需求 1 & 4] autofocus: true 会让光标自动进入，并弹出键盘
          autofocus: true,
          // [需求 5] 键盘的确认键变成搜索键
          textInputAction: TextInputAction.search,
          // 注：Flutter 暂不支持原生键盘按键视觉变灰 (enablesReturnKeyAutomatically)
          // 但此处逻辑已确保无内容时不执行搜索，且不收起键盘，体验上接近“禁用”
          onSubmitted: (_) => _onSearch(),
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: widget.isConsumerMode ? "搜索感兴趣的地点或供给..." : "搜索附近的任务需求...",
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey[400]),
          ),
        ),
        // [需求 3] 右侧有搜索按钮
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton(
              // [需求 1] 如果没有文字，onPressed 设为 null (禁用状态)
              onPressed: _hasText ? _onSearch : null,
              child: Text(
                '搜索',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  // [需求 1] 视觉上变灰
                  color: _hasText ? Colors.blue : Colors.grey,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              "输入关键词开始搜索",
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final item = _searchResults[index];
        String displayTitle = "";

        if (item is Task) {
          displayTitle = "需求 #${item.id}: ${item.title} - 预算 \$${item.budget}";
        } else if (item is Supply) {
          displayTitle = "供给 #${item.id}: ${item.title} - 评分 ${item.rating}";
        } else {
          displayTitle = item.toString();
        }

        // [需求 2] 搜索结果列表样式与主页面相同
        return Container(
          height: 110,
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
    );
  }
}