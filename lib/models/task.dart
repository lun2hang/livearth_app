class Task {
  final int id;
  final String userId;
  final String title;
  final String? description;
  final double lat;
  final double lng;
  final String? addressText;
  final String? placeId;
  final String? formattedAddress;
  final double? distanceKm;
  final double budget;
  final String status;
  final String createdAt;
  final String validFrom;
  final String validTo;
  final String? nickname;
  final String? avatar;
  final String? coverImageUrl;

  Task({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.lat,
    required this.lng,
    this.addressText,
    this.placeId,
    this.formattedAddress,
    this.distanceKm,
    required this.budget,
    required this.status,
    required this.createdAt,
    required this.validFrom,
    required this.validTo,
    this.nickname,
    this.avatar,
    this.coverImageUrl,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as int,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      addressText: json['address_text'] as String?,
      placeId: json['place_id'] as String?,
      formattedAddress: json['formatted_address'] as String?,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      budget: (json['budget'] as num).toDouble(),
      status: json['status'] as String,
      createdAt: json['created_at'] as String,
      validFrom: json['valid_from'] as String,
      validTo: json['valid_to'] as String,
      nickname: json['nickname'] as String?,
      avatar: json['avatar'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'lat': lat,
      'lng': lng,
      'address_text': addressText,
      'place_id': placeId,
      'formatted_address': formattedAddress,
      'budget': budget,
      'status': status,
      'created_at': createdAt,
      'valid_from': validFrom,
      'valid_to': validTo,
      'cover_image_url': coverImageUrl,
    };
  }
}