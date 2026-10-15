/// Model for a SafetyTimer row returned by the backend.
class SafetyTimerModel {
  final String id;
  final String userId;
  final String status; // ACTIVE | CHECKED_IN | CANCELLED | EXPIRED
  final int durationMinutes;
  final DateTime expiresAt;
  final double? latitude;
  final double? longitude;
  final DateTime? locationAt;
  final bool alertFired;
  final DateTime? checkedInAt;
  final DateTime? cancelledAt;
  final DateTime? expiredAt;
  final DateTime createdAt;

  const SafetyTimerModel({
    required this.id,
    required this.userId,
    required this.status,
    required this.durationMinutes,
    required this.expiresAt,
    this.latitude,
    this.longitude,
    this.locationAt,
    required this.alertFired,
    this.checkedInAt,
    this.cancelledAt,
    this.expiredAt,
    required this.createdAt,
  });

  bool get isActive => status == 'ACTIVE';
  bool get isExpired => status == 'EXPIRED';
  bool get isCheckedIn => status == 'CHECKED_IN';
  bool get isCancelled => status == 'CANCELLED';

  /// Remaining time in seconds (server-calculated or local fallback).
  int remainingSeconds([int? serverRemainingMs]) {
    if (serverRemainingMs != null) {
      return (serverRemainingMs / 1000).floor().clamp(0, double.infinity).toInt();
    }
    final diff = expiresAt.difference(DateTime.now());
    return diff.isNegative ? 0 : diff.inSeconds;
  }

  SafetyTimerModel copyWith({
    String? id,
    String? userId,
    String? status,
    int? durationMinutes,
    DateTime? expiresAt,
    double? latitude,
    double? longitude,
    DateTime? locationAt,
    bool? alertFired,
    DateTime? checkedInAt,
    DateTime? cancelledAt,
    DateTime? expiredAt,
    DateTime? createdAt,
  }) {
    return SafetyTimerModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      expiresAt: expiresAt ?? this.expiresAt,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationAt: locationAt ?? this.locationAt,
      alertFired: alertFired ?? this.alertFired,
      checkedInAt: checkedInAt ?? this.checkedInAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      expiredAt: expiredAt ?? this.expiredAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory SafetyTimerModel.fromJson(Map<String, dynamic> json) {
    return SafetyTimerModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? json['userId'] ?? '',
      status: json['status'] ?? 'ACTIVE',
      durationMinutes: int.tryParse(json['duration_minutes'].toString()) ?? 0,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'])
          : DateTime.now(),
      latitude: json['latitude'] != null
          ? double.tryParse(json['latitude'].toString())
          : null,
      longitude: json['longitude'] != null
          ? double.tryParse(json['longitude'].toString())
          : null,
      locationAt: json['location_at'] != null
          ? DateTime.parse(json['location_at'])
          : null,
      alertFired: json['alert_fired'] == true,
      checkedInAt: json['checked_in_at'] != null
          ? DateTime.parse(json['checked_in_at'])
          : null,
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.parse(json['cancelled_at'])
          : null,
      expiredAt: json['expired_at'] != null
          ? DateTime.parse(json['expired_at'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'status': status,
      'duration_minutes': durationMinutes,
      'expires_at': expiresAt.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'location_at': locationAt?.toIso8601String(),
      'alert_fired': alertFired,
      'checked_in_at': checkedInAt?.toIso8601String(),
      'cancelled_at': cancelledAt?.toIso8601String(),
      'expired_at': expiredAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
