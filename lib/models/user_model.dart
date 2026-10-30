class UserModel {
  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String? preferredLanguage;
  final String? createdAt;
  final String? updatedAt;

  UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    this.preferredLanguage,
    this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      fullName: json['fullName'] ?? json['full_name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      preferredLanguage: json['preferredLanguage'] ?? json['preferred_language'] ?? 'en',
      createdAt: json['createdAt'] ?? json['created_at'],
      updatedAt: json['updatedAt'] ?? json['updated_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'preferredLanguage': preferredLanguage,
      'preferred_language': preferredLanguage,
      'createdAt': createdAt,
      'created_at': createdAt,
      'updatedAt': updatedAt,
      'updated_at': updatedAt,
    };
  }
}
