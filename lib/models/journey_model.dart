import 'dart:convert';

/// Model for a live journey session
class JourneyModel {
  final String id;
  final String userId;
  final String status; // ACTIVE | COMPLETED | CANCELLED
  final String? destination;
  final String? trackingToken;
  final String? trackingUrl;
  final double? startLatitude;
  final double? startLongitude;
  final double? lastKnownLatitude;
  final double? lastKnownLongitude;
  final DateTime? lastUpdatedAt;
  final bool routeDeviationEnabled;
  final int deviationThresholdMeters;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int breadcrumbCount;
  final Map<String, dynamic>? latestLocation;

  const JourneyModel({
    required this.id,
    required this.userId,
    required this.status,
    this.destination,
    this.trackingToken,
    this.trackingUrl,
    this.startLatitude,
    this.startLongitude,
    this.lastKnownLatitude,
    this.lastKnownLongitude,
    this.lastUpdatedAt,
    required this.routeDeviationEnabled,
    required this.deviationThresholdMeters,
    required this.startedAt,
    this.endedAt,
    this.breadcrumbCount = 0,
    this.latestLocation,
  });

  bool get isActive => status == 'ACTIVE';

  factory JourneyModel.fromJson(Map<String, dynamic> json) {
    return JourneyModel(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      status: json['status'] as String? ?? 'ACTIVE',
      destination: json['destination'] as String?,
      trackingToken: json['tracking_token'] as String?,
      trackingUrl: json['tracking_url'] as String?,
      startLatitude: _toDouble(json['start_latitude']),
      startLongitude: _toDouble(json['start_longitude']),
      lastKnownLatitude: _toDouble(json['last_known_latitude']),
      lastKnownLongitude: _toDouble(json['last_known_longitude']),
      lastUpdatedAt: _toDateTime(json['last_updated_at']),
      routeDeviationEnabled: json['route_deviation_enabled'] as bool? ?? true,
      deviationThresholdMeters:
          json['deviation_threshold_meters'] as int? ?? 150,
      startedAt: _toDateTime(json['started_at']) ?? DateTime.now(),
      endedAt: _toDateTime(json['ended_at']),
      breadcrumbCount: int.tryParse(json['breadcrumb_count']?.toString() ?? '0') ?? 0,
      latestLocation: json['latest_location'] as Map<String, dynamic>?,
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    return double.tryParse(v.toString());
  }

  static DateTime? _toDateTime(dynamic v) {
    if (v == null) return null;
    try {
      return DateTime.parse(v.toString());
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'status': status,
        'destination': destination,
        'tracking_token': trackingToken,
        'tracking_url': trackingUrl,
        'start_latitude': startLatitude,
        'start_longitude': startLongitude,
        'last_known_latitude': lastKnownLatitude,
        'last_known_longitude': lastKnownLongitude,
        'route_deviation_enabled': routeDeviationEnabled,
        'deviation_threshold_meters': deviationThresholdMeters,
        'started_at': startedAt.toIso8601String(),
        'ended_at': endedAt?.toIso8601String(),
        'breadcrumb_count': breadcrumbCount,
      };
}
