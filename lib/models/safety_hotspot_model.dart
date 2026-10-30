import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

enum HotspotRiskLevel {
  yellow,
  orange,
  red,
}

enum HotspotVerificationStatus {
  communityReported,
  communityVerified,
  disputed,
}

class HotspotReportItem {
  final String id;
  final String category;
  final String title;
  final String description;
  final String? locationName;
  final DateTime createdAt;
  final int upvotesCount;
  final int confirmationsCount;
  final String authorFullName;

  const HotspotReportItem({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    this.locationName,
    required this.createdAt,
    this.upvotesCount = 0,
    this.confirmationsCount = 0,
    this.authorFullName = 'Nirbhay Member',
  });

  factory HotspotReportItem.fromJSON(Map<String, dynamic> json) {
    return HotspotReportItem(
      id: json['id']?.toString() ?? '',
      category: json['category']?.toString() ?? 'OTHER',
      title: json['title']?.toString() ?? 'Safety Report',
      description: json['description']?.toString() ?? '',
      locationName: json['locationName']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      upvotesCount: json['upvotesCount'] is int
          ? json['upvotesCount']
          : int.tryParse(json['upvotesCount']?.toString() ?? '0') ?? 0,
      confirmationsCount: json['confirmationsCount'] is int
          ? json['confirmationsCount']
          : int.tryParse(json['confirmationsCount']?.toString() ?? '0') ?? 0,
      authorFullName: json['authorFullName']?.toString() ?? 'Nirbhay Member',
    );
  }
}

class HotspotCommentItem {
  final String id;
  final String postId;
  final String content;
  final DateTime createdAt;
  final String authorName;

  const HotspotCommentItem({
    required this.id,
    required this.postId,
    required this.content,
    required this.createdAt,
    required this.authorName,
  });

  factory HotspotCommentItem.fromJSON(Map<String, dynamic> json) {
    return HotspotCommentItem(
      id: json['id']?.toString() ?? '',
      postId: json['postId']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      authorName: json['authorName']?.toString() ?? 'Nirbhay Member',
    );
  }
}

class SafetyHotspotModel {
  final String id;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final double riskScore;
  final HotspotRiskLevel riskLevel;
  final String primaryCategory;
  final Map<String, int> categoryCounts;
  final int reportCount;
  final int independentAuthorCount;
  final DateTime latestReportAt;
  final HotspotVerificationStatus verificationStatus;
  final String locationName;
  final String summary;
  final int confirmationsCount;
  final int disputesCount;
  final List<HotspotReportItem> reports;
  final List<HotspotCommentItem> comments;

  const SafetyHotspotModel({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.riskScore,
    required this.riskLevel,
    required this.primaryCategory,
    this.categoryCounts = const {},
    required this.reportCount,
    required this.independentAuthorCount,
    required this.latestReportAt,
    required this.verificationStatus,
    required this.locationName,
    required this.summary,
    this.confirmationsCount = 0,
    this.disputesCount = 0,
    this.reports = const [],
    this.comments = const [],
  });

  factory SafetyHotspotModel.fromJSON(Map<String, dynamic> json) {
    final center = json['center'] as Map<String, dynamic>? ?? {};
    final lat = center['latitude'] != null
        ? (center['latitude'] as num).toDouble()
        : (json['latitude'] as num?)?.toDouble() ?? 0.0;
    final lng = center['longitude'] != null
        ? (center['longitude'] as num).toDouble()
        : (json['longitude'] as num?)?.toDouble() ?? 0.0;

    final riskLevelStr = (json['riskLevel']?.toString() ?? 'YELLOW').toUpperCase();
    HotspotRiskLevel level;
    if (riskLevelStr == 'RED') {
      level = HotspotRiskLevel.red;
    } else if (riskLevelStr == 'ORANGE') {
      level = HotspotRiskLevel.orange;
    } else {
      level = HotspotRiskLevel.yellow;
    }

    final verStr = (json['verificationStatus']?.toString() ?? '').toUpperCase();
    HotspotVerificationStatus ver;
    if (verStr == 'COMMUNITY_VERIFIED') {
      ver = HotspotVerificationStatus.communityVerified;
    } else if (verStr == 'DISPUTED') {
      ver = HotspotVerificationStatus.disputed;
    } else {
      ver = HotspotVerificationStatus.communityReported;
    }

    final catCountsRaw = json['categoryCounts'] as Map<String, dynamic>? ?? {};
    final catCounts = catCountsRaw.map((k, v) => MapEntry(k, (v as num).toInt()));

    final rawReports = json['reports'] as List<dynamic>? ?? [];
    final reportsList = rawReports
        .whereType<Map<String, dynamic>>()
        .map((r) => HotspotReportItem.fromJSON(r))
        .toList();

    final rawComments = json['comments'] as List<dynamic>? ?? [];
    final commentsList = rawComments
        .whereType<Map<String, dynamic>>()
        .map((c) => HotspotCommentItem.fromJSON(c))
        .toList();

    return SafetyHotspotModel(
      id: json['id']?.toString() ?? '',
      latitude: lat,
      longitude: lng,
      radiusMeters: (json['radiusMeters'] as num?)?.toDouble() ?? 200.0,
      riskScore: (json['riskScore'] as num?)?.toDouble() ?? 1.0,
      riskLevel: level,
      primaryCategory: json['primaryCategory']?.toString() ?? 'OTHER',
      categoryCounts: catCounts,
      reportCount: (json['reportCount'] as num?)?.toInt() ?? 1,
      independentAuthorCount: (json['independentAuthorCount'] as num?)?.toInt() ?? 1,
      latestReportAt: json['latestReportAt'] != null
          ? DateTime.tryParse(json['latestReportAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      verificationStatus: ver,
      locationName: json['locationName']?.toString() ?? 'Reported Safety Area',
      summary: json['summary']?.toString() ?? 'Community-reported safety concern.',
      confirmationsCount: (json['confirmationsCount'] as num?)?.toInt() ?? 0,
      disputesCount: (json['disputesCount'] as num?)?.toInt() ?? 0,
      reports: reportsList,
      comments: commentsList,
    );
  }

  Color get color {
    switch (riskLevel) {
      case HotspotRiskLevel.red:
        return const Color(0xFFE53935);
      case HotspotRiskLevel.orange:
        return const Color(0xFFFB8C00);
      case HotspotRiskLevel.yellow:
        return const Color(0xFFFDD835);
    }
  }

  Color get borderColor {
    switch (riskLevel) {
      case HotspotRiskLevel.red:
        return const Color(0xFFB71C1C);
      case HotspotRiskLevel.orange:
        return const Color(0xFFE65100);
      case HotspotRiskLevel.yellow:
        return const Color(0xFFF57F17);
    }
  }

  String localizedRiskLevelLabel(AppLocalizations l10n) {
    switch (riskLevel) {
      case HotspotRiskLevel.red:
        return l10n.translate('hotspotRiskHigh');
      case HotspotRiskLevel.orange:
        return l10n.translate('hotspotRiskModerate');
      case HotspotRiskLevel.yellow:
        return l10n.translate('hotspotRiskLow');
    }
  }

  String localizedVerificationLabel(AppLocalizations l10n) {
    switch (verificationStatus) {
      case HotspotVerificationStatus.communityVerified:
        return l10n.translate('hotspotVerified');
      case HotspotVerificationStatus.disputed:
        return l10n.translate('hotspotDisputed');
      case HotspotVerificationStatus.communityReported:
        return l10n.translate('hotspotCommunityReported');
    }
  }

  String localizedCategoryLabel(AppLocalizations l10n) {
    switch (primaryCategory.toUpperCase()) {
      case 'HARASSMENT':
        return l10n.catHarassment;
      case 'UNSAFE_AREA':
        return l10n.catUnsafeArea;
      case 'SUSPICIOUS_ACTIVITY':
        return l10n.catSuspiciousActivity;
      case 'THEFT':
        return l10n.catTheft;
      case 'ROAD_SAFETY':
        return l10n.catRoadSafety;
      case 'LOST_PERSON':
        return l10n.catLostPerson;
      case 'HELPFUL_INFO':
        return l10n.catHelpfulInfo;
      default:
        return l10n.catOther;
    }
  }
}
