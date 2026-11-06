class UserModel {
  final int id;
  final String name;
  final String email;
  final String role;
  final String? phone;
  final bool isVerified;
  final String? createdAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.isVerified = false,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      phone: json['phone'] as String?,
      isVerified: json['is_verified'] == true || json['is_verified'] == 1,
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'phone': phone,
      'is_verified': isVerified,
      'created_at': createdAt,
    };
  }

  bool get isHost => role == 'host' || role == 'admin';
  bool get isAdmin => role == 'admin';
}

