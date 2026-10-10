import 'package:flutter/material.dart';

class EmergencyContactModel {
  final String id;
  final String userId;
  final String name;
  final String phone;
  final String relationship;
  final bool autoAlert;
  final String? createdAt;
  final String? updatedAt;

  EmergencyContactModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.phone,
    this.relationship = '',
    required this.autoAlert,
    this.createdAt,
    this.updatedAt,
  });

  factory EmergencyContactModel.fromJson(Map<String, dynamic> json) {
    return EmergencyContactModel(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? json['user_id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['contactName']?.toString() ?? '',
      phone: json['phone']?.toString() ?? json['phoneNumber']?.toString() ?? '',
      relationship: json['relationship']?.toString() ?? '',
      autoAlert: json['autoAlert'] == true || json['auto_alert'] == true,
      createdAt: json['createdAt']?.toString() ?? json['created_at']?.toString(),
      updatedAt: json['updatedAt']?.toString() ?? json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'user_id': userId,
      'name': name,
      'contactName': name,
      'phone': phone,
      'phoneNumber': phone,
      'relationship': relationship,
      'autoAlert': autoAlert,
      'auto_alert': autoAlert,
      if (createdAt != null) 'createdAt': createdAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }

  /// Copy with helper for state updates
  EmergencyContactModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? phone,
    String? relationship,
    bool? autoAlert,
    String? createdAt,
    String? updatedAt,
  }) {
    return EmergencyContactModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      relationship: relationship ?? this.relationship,
      autoAlert: autoAlert ?? this.autoAlert,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Calculate user initials for contact avatar
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  /// Generate dynamic pastel color based on name hash
  Color get avatarColor {
    final palette = const [
      Color(0xFFE8C8D8),
      Color(0xFFC8D8E8),
      Color(0xFFD8E8C8),
      Color(0xFFE8D8C8),
      Color(0xFFD8C8E8),
      Color(0xFFC8E8E8),
    ];
    final hash = name.codeUnits.fold(0, (prev, elem) => prev + elem);
    return palette[hash % palette.length];
  }
}
