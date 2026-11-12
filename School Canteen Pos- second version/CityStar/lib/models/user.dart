class User {
  final int id;
  final int? shopId;
  final String username;
  final String role;
  final bool isActive;

  User({
    required this.id,
    this.shopId,
    required this.username,
    required this.role,
    required this.isActive,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      shopId: json['shop_id'],
      username: json['username'],
      role: json['role'],
      isActive: json['is_active'] == 1 || json['is_active'] == true,
    );
  }
}
