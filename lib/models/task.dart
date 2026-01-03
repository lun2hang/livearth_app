class Task {
  final int id;
  final String userId;
  final String title;
  final String? description;
  final double lat;
  final double lng;
  final double budget;
  final String status;
  final String createdAt;
  final String validFrom;
  final String validTo;

  Task({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.lat,
    required this.lng,
    required this.budget,
    required this.status,
    required this.createdAt,
    required this.validFrom,
    required this.validTo,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as int,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      budget: (json['budget'] as num).toDouble(),
      status: json['status'] as String,
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
      'budget': budget,
      'status': status,
      'created_at': createdAt,
      'valid_from': validFrom,
      'valid_to': validTo,
    };
  }
}