class Supply {
  final String id;
  final String userId;
  final String title;
  final String description;
  final double lat;
  final double lng;
  final double rating;
  final String createdAt;
  final String validFrom;
  final String validTo;

  Supply({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.lat,
    required this.lng,
    required this.rating,
    required this.createdAt,
    required this.validFrom,
    required this.validTo,
  });

  factory Supply.fromJson(Map<String, dynamic> json) {
    return Supply(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      rating: (json['rating'] as num).toDouble(),
      createdAt: json['created_at'] as String,
      validFrom: json['valid_from'] as String,
      validTo: json['valid_to'] as String,
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
      'rating': rating,
      'created_at': createdAt,
      'valid_from': validFrom,
      'valid_to': validTo,
    };
  }
}