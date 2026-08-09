import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geocoding/geocoding.dart';
import 'user_profile_screen.dart'; // 导入用户Profile视图
import 'models/supply.dart';
import 'main.dart'; // 导入 MockAPI

class SupplyDetailScreen extends StatefulWidget {
  final Supply supply;

  const SupplyDetailScreen({super.key, required this.supply});

  @override
  State<SupplyDetailScreen> createState() => _SupplyDetailScreenState();
}

class _SupplyDetailScreenState extends State<SupplyDetailScreen> {
  bool _isOwner = false;
  bool _isLoading = false;
  late Supply _supply = widget.supply;
  String _displayAddress = '';

  @override
  void initState() {
    super.initState();
    _checkOwner();
    _fetchDetail();
    _resolveAddress();
  }

  Future<void> _fetchDetail() async {
    final detailedSupply = await MockAPI.fetchSupplyDetail(_supply.id);
    if (detailedSupply != null && mounted) {
      setState(() {
        _supply = detailedSupply;
      });
      _checkOwner();
      _resolveAddress();
    }
  }

  Future<void> _resolveAddress() async {
    // 优先使用格式化地址或选定地址名
    if (_supply.formattedAddress != null && _supply.formattedAddress!.isNotEmpty) {
      if (_supply.addressText != null &&
          _supply.addressText!.isNotEmpty &&
          _supply.addressText != _supply.formattedAddress) {
        if (mounted) {
          setState(() {
            _displayAddress = "${_supply.addressText}, ${_supply.formattedAddress}";
          });
        }
        return;
      }
      if (mounted) {
        setState(() {
          _displayAddress = _supply.formattedAddress!;
        });
      }
      return;
    }

    if (_supply.addressText != null && _supply.addressText!.isNotEmpty) {
      if (mounted) {
        setState(() {
          _displayAddress = _supply.addressText!;
        });
      }
      return;
    }

    // 如果未存文字，则动态对经纬度进行逆地理编码，拼装为美式地址顺序：[地名/街道], [城市], [州/省], [国家]
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(_supply.lat, _supply.lng);
      if (placemarks.isNotEmpty && mounted) {
        final p = placemarks.first;
        final parts = [
          p.name ?? p.street, // 地名/街道
          p.locality ?? p.subLocality, // 城市
          p.administrativeArea, // 州/省
          p.country, // 国家
        ].where((e) => e != null && e.isNotEmpty).toList();

        if (parts.isNotEmpty) {
          setState(() {
            _displayAddress = parts.join(', ');
          });
          return;
        }
      }
    } catch (e) {
      print("解析地址失败: $e");
    }

    if (mounted) {
      setState(() {
        _displayAddress = "位置坐标: ${_supply.lat.toStringAsFixed(4)}, ${_supply.lng.toStringAsFixed(4)}";
      });
    }
  }

  Future<void> _checkOwner() async {
    const storage = FlutterSecureStorage();
    final currentUserId = await storage.read(key: 'user_id');
    if (mounted && currentUserId != null) {
      setState(() {
        _isOwner = currentUserId == _supply.userId;
      });
    }
  }

  Future<void> _handleCancel() async {
    // 弹窗确认
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange),
            SizedBox(height: 16),
            Text('取消后无法恢复，您确定要取消这个供给吗？', textAlign: TextAlign.center),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('再想想'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('确定取消'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    final success = await MockAPI.cancelEntry(_supply.id, 'supply');
    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('取消成功')));
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('取消失败，请重试')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('供给详情'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 1,
      ),
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 视频/封面图占位
            if (_supply.coverImageUrl != null && _supply.coverImageUrl!.isNotEmpty) ...[
              Container(
                width: double.infinity,
                height: 240,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: NetworkImage(_supply.coverImageUrl!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 标题卡片
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _supply.title,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  // 位置信息 (位于标题正下方，全页唯一)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined, size: 16, color: Colors.orange),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _displayAddress.isNotEmpty ? _displayAddress : "正在解析位置...",
                          style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                        ),
                      ),
                      if (_supply.distanceKm != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          "${_supply.distanceKm} km",
                          style: const TextStyle(fontSize: 13, color: Colors.orange, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // 缩小后的发布者信息 (点击跳转至个人主页)
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UserProfileScreen(
                                userId: _supply.userId,
                                initialNickname: _supply.nickname,
                                initialAvatar: _supply.avatar,
                              ),
                            ),
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              backgroundImage: _supply.avatar != null && _supply.avatar!.isNotEmpty
                                  ? NetworkImage(_supply.avatar!)
                                  : null,
                              radius: 12,
                              backgroundColor: Colors.grey[200],
                              child: _supply.avatar == null || _supply.avatar!.isEmpty
                                  ? const Icon(Icons.person, size: 16, color: Colors.grey)
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _supply.nickname ?? "匿名用户",
                              style: TextStyle(fontSize: 13, color: Colors.grey[700], decoration: TextDecoration.underline),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: Colors.orange, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            "${_supply.rating}",
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          "¥${_supply.price}",
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        _supply.status,
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // 描述信息
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("详情", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    _supply.description.isNotEmpty ? _supply.description : "暂无描述",
                    style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 其他信息
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildInfoRow(Icons.camera_roll_outlined, "ID", "${_supply.id}"),
                  const Divider(height: 24),
                  _buildInfoRow(Icons.access_time, "发布时间", _formatTime(_supply.createdAt)),
                  const Divider(height: 24),
                  _buildInfoRow(Icons.timer_outlined, "有效期", "${_formatTime(_supply.validFrom)}\n至 ${_formatTime(_supply.validTo)}"),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _isOwner
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildConsumerButton(),
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _isOwner ? _buildOwnerFab() : null,
    );
  }

  Widget? _buildOwnerFab() {
    if (['created', 'matched'].contains(_supply.status)) {
      return SizedBox(
        width: MediaQuery.of(context).size.width / 3,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _handleCancel,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[300],
            foregroundColor: Colors.black87,
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('取消供给', style: TextStyle(fontSize: 16)),
        ),
      );
    }
    return null;
  }

  Widget _buildConsumerButton() {
    return ElevatedButton(
      onPressed: () async {
        final success = await MockAPI.bookSupply(_supply.id);
        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('预订成功！')));
            Navigator.pop(context);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('预订失败，请重试')));
          }
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: const Text('立即预订', style: TextStyle(fontSize: 16)),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.grey)),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w500),
          textAlign: TextAlign.right,
        ),
      ],
    );
  }

  String _formatTime(String iso) {
    try {
      if (!iso.endsWith('Z')) iso += 'Z';
      final dt = DateTime.parse(iso).toLocal();
      return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return iso;
    }
  }
}
