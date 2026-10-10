class SosIncidentModel {
  final String id;
  final String userId;
  final String status;
  final double? latitude;
  final double? longitude;
  final DateTime activatedAt;
  final DateTime? resolvedAt;
  final DateTime? cancelledAt;
  final String notificationStatus;

  SosIncidentModel({
    required this.id,
    required this.userId,
    required this.status,
    this.latitude,
    this.longitude,
    required this.activatedAt,
    this.resolvedAt,
    this.cancelledAt,
    required this.notificationStatus,
  });

  factory SosIncidentModel.fromJson(Map<String, dynamic> json) {
    return SosIncidentModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? json['userId'] ?? '',
      status: json['status'] ?? 'ACTIVE',
      latitude: json['latitude'] != null ? double.tryParse(json['latitude'].toString()) : null,
      longitude: json['longitude'] != null ? double.tryParse(json['longitude'].toString()) : null,
      activatedAt: json['activated_at'] != null 
          ? DateTime.parse(json['activated_at']) 
          : DateTime.now(),
      resolvedAt: json['resolved_at'] != null ? DateTime.parse(json['resolved_at']) : null,
      cancelledAt: json['cancelled_at'] != null ? DateTime.parse(json['cancelled_at']) : null,
      notificationStatus: json['notification_status'] ?? json['notificationStatus'] ?? 'PENDING',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'status': status,
      'latitude': latitude,
      'longitude': longitude,
      'activated_at': activatedAt.toIso8601String(),
      'resolved_at': resolvedAt?.toIso8601String(),
      'cancelled_at': cancelledAt?.toIso8601String(),
      'notification_status': notificationStatus,
    };
  }

  bool get isActive => status == 'ACTIVE';
}

class SosNotificationModel {
  final String id;
  final String sosId;
  final String? contactId;
  final String contactName;
  final String contactPhone;
  final String channel;
  final String status;
  final String? providerMessageId;
  final String? errorMessage;
  final DateTime? sentAt;

  SosNotificationModel({
    required this.id,
    required this.sosId,
    this.contactId,
    required this.contactName,
    required this.contactPhone,
    required this.channel,
    required this.status,
    this.providerMessageId,
    this.errorMessage,
    this.sentAt,
  });

  factory SosNotificationModel.fromJson(Map<String, dynamic> json) {
    return SosNotificationModel(
      id: json['id'] ?? '',
      sosId: json['sos_id'] ?? json['sosId'] ?? '',
      contactId: json['contact_id'] ?? json['contactId'],
      contactName: json['contact_name'] ?? json['contactName'] ?? '',
      contactPhone: json['contact_phone'] ?? json['contactPhone'] ?? '',
      channel: json['channel'] ?? 'SMS',
      status: json['status'] ?? 'PENDING',
      providerMessageId: json['provider_message_id'] ?? json['providerMessageId'],
      errorMessage: json['error_message'] ?? json['errorMessage'],
      sentAt: json['sent_at'] != null ? DateTime.parse(json['sent_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sos_id': sosId,
      'contact_id': contactId,
      'contact_name': contactName,
      'contact_phone': contactPhone,
      'channel': channel,
      'status': status,
      'provider_message_id': providerMessageId,
      'error_message': errorMessage,
      'sent_at': sentAt?.toIso8601String(),
    };
  }
}
