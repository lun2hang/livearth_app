class UserInfo {
  final String id;
  final String username;
  final String? nickname;
  final String? avatar;

  UserInfo({required this.id, required this.username, this.nickname, this.avatar});

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      id: json['id'] as String,
      username: json['username'] as String,
      nickname: json['nickname'] as String?,
      avatar: json['avatar'] as String?,
    );
  }
}

class OrderWithDetails {
  final int id;
  final UserInfo consumer;
  final UserInfo provider;
  final int? taskId;
  final int? supplyId;
  final double amount;
  final String status;
  final String createdAt;
  final String? startTime;

  OrderWithDetails({
    required this.id,
    required this.consumer,
    required this.provider,
    this.taskId,
    this.supplyId,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.startTime,
  });

  factory OrderWithDetails.fromJson(Map<String, dynamic> json) {
    return OrderWithDetails(
      id: json['id'] as int,
      consumer: json['consumer'] != null
          ? UserInfo.fromJson(json['consumer'] as Map<String, dynamic>)
          : UserInfo(id: "unknown", username: "未知用户"),
      provider: json['provider'] != null
          ? UserInfo.fromJson(json['provider'] as Map<String, dynamic>)
          : UserInfo(id: "unknown", username: "未知用户"),
      taskId: json['task_id'] as int?,
      supplyId: json['supply_id'] as int?,
      amount: (json['amount'] as num).toDouble(),
      status: json['status'] as String,
      createdAt: json['created_at'] as String,
      startTime: json['start_time'] as String?,
    );
  }
}