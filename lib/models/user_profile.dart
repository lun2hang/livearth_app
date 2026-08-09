class UserProfilePublic {
  final String userId;
  final String username;
  final String? nickname;
  final String? avatar;
  final int historySuppliesCount;
  final int historyTasksCount;
  final int successfulDealsCount;

  UserProfilePublic({
    required this.userId,
    required this.username,
    this.nickname,
    this.avatar,
    this.historySuppliesCount = 0,
    this.historyTasksCount = 0,
    this.successfulDealsCount = 0,
  });

  factory UserProfilePublic.fromJson(Map<String, dynamic> json) {
    return UserProfilePublic(
      userId: json['user_id'] ?? '',
      username: json['username'] ?? '',
      nickname: json['nickname'],
      avatar: json['avatar'],
      historySuppliesCount: json['history_supplies_count'] ?? 0,
      historyTasksCount: json['history_tasks_count'] ?? 0,
      successfulDealsCount: json['successful_deals_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'username': username,
      'nickname': nickname,
      'avatar': avatar,
      'history_supplies_count': historySuppliesCount,
      'history_tasks_count': historyTasksCount,
      'successful_deals_count': successfulDealsCount,
    };
  }
}
