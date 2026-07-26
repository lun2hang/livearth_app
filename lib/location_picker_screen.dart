import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'main.dart'; // 导入 DioClient

class SelectedLocation {
  final double lat;
  final double lng;
  final String? addressText;
  final String? formattedAddress;
  final String? placeId;

  SelectedLocation({
    required this.lat,
    required this.lng,
    this.addressText,
    this.formattedAddress,
    this.placeId,
  });
}

class SearchResultItem {
  final double lat;
  final double lng;
  final String title;
  final String subtitle;
  final String? placeId;

  SearchResultItem({
    required this.lat,
    required this.lng,
    required this.title,
    required this.subtitle,
    this.placeId,
  });
}

class LocationPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const LocationPickerScreen({
    super.key,
    this.initialLat,
    this.initialLng,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  GoogleMapController? _mapController;
  late LatLng _currentCenter;
  
  String _addressText = '正定位到当前位置...';
  String _formattedAddress = '';
  String? _placeId;
  bool _isLoadingAddress = false;

  final TextEditingController _searchController = TextEditingController();
  List<SearchResultItem> _searchResults = [];
  bool _isSearching = false;
  bool _showSearchResults = false;
  Timer? _debounceTimer;

  bool _hasLocationPermission = false;

  @override
  void initState() {
    super.initState();
    _currentCenter = LatLng(
      widget.initialLat ?? 35.6595, // 默认东京
      widget.initialLng ?? 139.7005,
    );
    _getUserCurrentLocation();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // 获取用户当前位置
  Future<void> _getUserCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _reverseGeocode(_currentCenter);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        if (mounted) {
          setState(() {
            _hasLocationPermission = true;
          });
        }
        // 添加 3 秒超时限制，防止 iOS 模拟器没有设置 Location 时无限等待
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 3),
        );
        final userLatLng = LatLng(position.latitude, position.longitude);
        if (mounted) {
          setState(() {
            _currentCenter = userLatLng;
          });
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(userLatLng, 15.0),
          );
          _reverseGeocode(userLatLng);
        }
      } else {
        _reverseGeocode(_currentCenter);
      }
    } catch (e) {
      print("获取定位超时/失败 (使用默认经纬度): $e");
      _reverseGeocode(_currentCenter);
    }
  }

  // 逆地理编码：把经纬度转换为美式顺序格式地址 ([地名/街道], [城市], [州/省], [国家])
  Future<void> _reverseGeocode(LatLng target) async {
    setState(() {
      _isLoadingAddress = true;
    });

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        target.latitude,
        target.longitude,
      );

      if (placemarks.isNotEmpty && mounted) {
        final place = placemarks.first;
        final name = place.name ?? place.street ?? place.subLocality ?? '地图选定位置';
        final parts = [
          place.subThoroughfare != null && place.thoroughfare != null
              ? '${place.subThoroughfare} ${place.thoroughfare}'
              : (place.street ?? place.thoroughfare),
          place.locality ?? place.subLocality,
          place.administrativeArea,
          place.country,
        ].where((e) => e != null && e.isNotEmpty).toList();

        final formattedStr = parts.isNotEmpty
            ? parts.join(', ')
            : '(${target.latitude.toStringAsFixed(4)}, ${target.longitude.toStringAsFixed(4)})';

        setState(() {
          _addressText = name.isNotEmpty ? name : '地图选定位置';
          _formattedAddress = formattedStr;
          _isLoadingAddress = false;
        });
      } else if (mounted) {
        setState(() {
          _addressText = '地图选定位置';
          _formattedAddress = '(${target.latitude.toStringAsFixed(4)}, ${target.longitude.toStringAsFixed(4)})';
          _isLoadingAddress = false;
        });
      }
    } catch (e) {
      print("逆地理编码失败: $e");
      if (mounted) {
        setState(() {
          _addressText = '地图选定位置';
          _formattedAddress = '(${target.latitude.toStringAsFixed(4)}, ${target.longitude.toStringAsFixed(4)})';
          _isLoadingAddress = false;
        });
      }
    }
  }

  // 搜索关键字查找地点 (Places Autocomplete + Geocoding 双重精准匹配)
  Future<void> _searchPlaces(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _showSearchResults = true;
    });

    List<SearchResultItem> results = [];
    const apiKey = "AIzaSyCNMKAegs37qzAcMuXZ0bxQ-rBrsBQicN8";

    // 1. 优先尝试请求 Google Places Autocomplete API (携带 iOS Bundle ID 报头穿透 Key 权限限制)
    try {
      final mapsDio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        headers: {
          'X-Ios-Bundle-Identifier': 'com.example.livearthApp',
          'X-Android-Package': 'com.example.livearth_app',
        },
      ));
      final response = await mapsDio.get(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json',
        queryParameters: {
          'input': trimmed,
          'key': apiKey,
        },
      );

      if (response.data != null) {
        final status = response.data['status'];
        if (status == 'OK') {
          final List<dynamic> predictions = response.data['predictions'];
          for (var p in predictions) {
            final placeId = p['place_id'] as String?;
            final mainText = p['structured_formatting']?['main_text'] ?? p['description'];
            final secondaryText = p['structured_formatting']?['secondary_text'] ?? p['description'];
            
            results.add(SearchResultItem(
              lat: 0.0,
              lng: 0.0,
              title: mainText,
              subtitle: secondaryText,
              placeId: placeId,
            ));
          }
        } else {
          print("🌐 Google Places Autocomplete 响应状态: $status, 错误信息: ${response.data['error_message']}");
        }
      }
    } catch (e) {
      print("Google Places Autocomplete 失败: $e");
    }

    // 2. 如果 Autocomplete 未返回，降级尝试 Google Geocoding API 直连
    if (results.isEmpty) {
      try {
        final mapsDio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
          headers: {
            'X-Ios-Bundle-Identifier': 'com.example.livearthApp',
            'X-Android-Package': 'com.example.livearth_app',
          },
        ));
        final response = await mapsDio.get(
          'https://maps.googleapis.com/maps/api/geocode/json',
          queryParameters: {
            'address': trimmed,
            'key': apiKey,
          },
        );

        if (response.data != null) {
          final status = response.data['status'];
          if (status == 'OK') {
            final List<dynamic> list = response.data['results'];
            for (var item in list) {
              final loc = item['geometry']['location'];
              final formattedAddr = item['formatted_address'] ?? trimmed;
              final placeId = item['place_id'];

              String title = trimmed;
              if (item['address_components'] != null && (item['address_components'] as List).isNotEmpty) {
                title = item['address_components'][0]['long_name'] ?? trimmed;
              }

              results.add(SearchResultItem(
                lat: (loc['lat'] as num).toDouble(),
                lng: (loc['lng'] as num).toDouble(),
                title: title,
                subtitle: formattedAddr,
                placeId: placeId,
              ));
            }
          } else {
            print("🌐 Google Geocoding API 响应状态: $status, 错误信息: ${response.data['error_message']}");
          }
        }
      } catch (e) {
        print("Google Geocoding API 请求错误: $e");
      }
    }

    // 3. 本地 Geocoding 兜底
    if (results.isEmpty) {
      try {
        List<Location> locations = await locationFromAddress(trimmed);
        for (var loc in locations) {
          try {
            List<Placemark> placemarks = await placemarkFromCoordinates(loc.latitude, loc.longitude);
            if (placemarks.isNotEmpty) {
              final p = placemarks.first;
              final titleName = p.name ?? p.street ?? trimmed;
              final subtitle = [
                p.street,
                p.subLocality ?? p.locality,
                p.administrativeArea,
                p.country
              ].where((e) => e != null && e.isNotEmpty).join(', ');

              results.add(SearchResultItem(
                lat: loc.latitude,
                lng: loc.longitude,
                title: titleName,
                subtitle: subtitle.isNotEmpty ? subtitle : '(${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)})',
              ));
            }
          } catch (_) {
            results.add(SearchResultItem(
              lat: loc.latitude,
              lng: loc.longitude,
              title: trimmed,
              subtitle: '(${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)})',
            ));
          }
        }
      } catch (e) {
        print("本地 Geocoding 失败: $e");
      }
    }

    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  // 选中搜索结果候选项
  Future<void> _selectSearchResultItem(SearchResultItem item) async {
    double lat = item.lat;
    double lng = item.lng;
    String formattedAddress = item.subtitle;

    // 如果是通过 Place Autocomplete 搜到的候选项，精确拉取其 place_id 对应的经纬度
    if ((lat == 0.0 && lng == 0.0) && item.placeId != null) {
      try {
        const apiKey = "AIzaSyCNMKAegs37qzAcMuXZ0bxQ-rBrsBQicN8";
        final mapsDio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
          headers: {
            'X-Ios-Bundle-Identifier': 'com.example.livearthApp',
            'X-Android-Package': 'com.example.livearth_app',
          },
        ));
        
        final response = await mapsDio.get(
          'https://maps.googleapis.com/maps/api/geocode/json',
          queryParameters: {
            'place_id': item.placeId,
            'key': apiKey,
          },
        );

        if (response.data != null && response.data['status'] == 'OK') {
          final result = response.data['results'][0];
          final loc = result['geometry']['location'];
          lat = (loc['lat'] as num).toDouble();
          lng = (loc['lng'] as num).toDouble();
          if (result['formatted_address'] != null) {
            formattedAddress = result['formatted_address'];
          }
        }
      } catch (e) {
        print("拉取 PlaceId 经纬度失败: $e");
      }
    }

    if (lat != 0.0 || lng != 0.0) {
      final newLatLng = LatLng(lat, lng);
      setState(() {
        _currentCenter = newLatLng;
        _addressText = item.title;
        _formattedAddress = formattedAddress;
        _placeId = item.placeId;
        _showSearchResults = false;
      });
      FocusScope.of(context).unfocus();
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(newLatLng, 15.0),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('选择位置', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Stack(
        children: [
          // 1. Google Map 地图层 (通过 EagerGestureRecognizer 完美支持双指缩放/旋转/全方向手势滑动)
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentCenter,
              zoom: 15.0,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
            },
            onCameraMove: (position) {
              _currentCenter = position.target;
            },
            onCameraIdle: () {
              _reverseGeocode(_currentCenter);
            },
            myLocationEnabled: _hasLocationPermission,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            zoomGesturesEnabled: true,
            scrollGesturesEnabled: true,
            rotateGesturesEnabled: true,
            tiltGesturesEnabled: true,
            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
              Factory<OneSequenceGestureRecognizer>(
                () => EagerGestureRecognizer(),
              ),
            },
          ),

          // 2. 地图中心固定 Pin Icon
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 36.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 44,
                    color: Colors.redAccent,
                  ),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.black26,
                      shape: BoxShape.circle,
                    ),
                  )
                ],
              ),
            ),
          ),

          // 3. 右下角快捷地图控制按钮组 (放大 / 缩小 / 我的位置)
          Positioned(
            right: 16,
            bottom: 180,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'zoom_in_btn',
                  backgroundColor: Colors.white,
                  onPressed: () {
                    _mapController?.animateCamera(CameraUpdate.zoomIn());
                  },
                  child: const Icon(Icons.add, color: Colors.black87),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoom_out_btn',
                  backgroundColor: Colors.white,
                  onPressed: () {
                    _mapController?.animateCamera(CameraUpdate.zoomOut());
                  },
                  child: const Icon(Icons.remove, color: Colors.black87),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'my_location_btn',
                  backgroundColor: Colors.white,
                  onPressed: _getUserCurrentLocation,
                  child: const Icon(Icons.my_location, color: Colors.blue),
                ),
              ],
            ),
          ),

          // 4. 顶部搜索栏
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      )
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: _searchPlaces,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: '搜索地点、地标或地址 (例如 San Jose)...',
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                      prefixIcon: IconButton(
                        icon: const Icon(Icons.search, color: Colors.blue),
                        onPressed: () => _searchPlaces(_searchController.text),
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _showSearchResults = false;
                                  _searchResults = [];
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    onChanged: (text) {
                      if (text.isEmpty) {
                        setState(() {
                          _showSearchResults = false;
                          _searchResults = [];
                        });
                        return;
                      }
                      // 防抖：停止输入 500ms 后自动触发搜索
                      _debounceTimer?.cancel();
                      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
                        _searchPlaces(text);
                      });
                    },
                  ),
                ),

                // 搜索结果下拉列表
                if (_showSearchResults)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    constraints: const BoxConstraints(maxHeight: 260),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        )
                      ],
                    ),
                    child: _isSearching
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : _searchResults.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text('未找到相关地点，请检查拼写', style: TextStyle(color: Colors.grey)),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                itemCount: _searchResults.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final item = _searchResults[index];
                                  return ListTile(
                                    leading: const Icon(Icons.place, color: Colors.redAccent),
                                    title: Text(
                                      item.title,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      item.subtitle,
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onTap: () => _selectSearchResultItem(item),
                                  );
                                },
                              ),
                  ),
              ],
            ),
          ),

          // 5. 底部选点信息确认卡片
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -3),
                  )
                ],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.redAccent, size: 28),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _isLoadingAddress ? '正在获取位置...' : _addressText,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formattedAddress,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _isLoadingAddress
                            ? null
                            : () {
                                final selected = SelectedLocation(
                                  lat: _currentCenter.latitude,
                                  lng: _currentCenter.longitude,
                                  addressText: _addressText,
                                  formattedAddress: _formattedAddress,
                                  placeId: _placeId,
                                );
                                Navigator.pop(context, selected);
                              },
                        child: const Text('确认选择此位置', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
