import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

enum CommunityCategory {
  suspiciousActivity,
  harassment,
  unsafeArea,
  theft,
  roadSafety,
  lostPerson,
  helpfulInfo,
  other,
}

extension CommunityCategoryExtension on CommunityCategory {
  String get apiKey {
    switch (this) {
      case CommunityCategory.suspiciousActivity:
        return 'SUSPICIOUS_ACTIVITY';
      case CommunityCategory.harassment:
        return 'HARASSMENT';
      case CommunityCategory.unsafeArea:
        return 'UNSAFE_AREA';
      case CommunityCategory.theft:
        return 'THEFT';
      case CommunityCategory.roadSafety:
        return 'ROAD_SAFETY';
      case CommunityCategory.lostPerson:
        return 'LOST_PERSON';
      case CommunityCategory.helpfulInfo:
        return 'HELPFUL_INFO';
      case CommunityCategory.other:
        return 'OTHER';
    }
  }

  String localizedLabel(AppLocalizations l10n) {
    switch (this) {
      case CommunityCategory.suspiciousActivity:
        return l10n.catSuspiciousActivity;
      case CommunityCategory.harassment:
        return l10n.catHarassment;
      case CommunityCategory.unsafeArea:
        return l10n.catUnsafeArea;
      case CommunityCategory.theft:
        return l10n.catTheft;
      case CommunityCategory.roadSafety:
        return l10n.catRoadSafety;
      case CommunityCategory.lostPerson:
        return l10n.catLostPerson;
      case CommunityCategory.helpfulInfo:
        return l10n.catHelpfulInfo;
      case CommunityCategory.other:
        return l10n.catOther;
    }
  }

  String get label {
    switch (this) {
      case CommunityCategory.suspiciousActivity:
        return 'Suspicious Activity';
      case CommunityCategory.harassment:
        return 'Harassment';
      case CommunityCategory.unsafeArea:
        return 'Unsafe Area';
      case CommunityCategory.theft:
        return 'Theft';
      case CommunityCategory.roadSafety:
        return 'Road Safety';
      case CommunityCategory.lostPerson:
        return 'Lost Person';
      case CommunityCategory.helpfulInfo:
        return 'Helpful Info';
      case CommunityCategory.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case CommunityCategory.suspiciousActivity:
        return Icons.visibility_outlined;
      case CommunityCategory.harassment:
        return Icons.shield_outlined;
      case CommunityCategory.unsafeArea:
        return Icons.warning_amber_rounded;
      case CommunityCategory.theft:
        return Icons.lock_outline;
      case CommunityCategory.roadSafety:
        return Icons.traffic_outlined;
      case CommunityCategory.lostPerson:
        return Icons.person_search_outlined;
      case CommunityCategory.helpfulInfo:
        return Icons.info_outline;
      case CommunityCategory.other:
        return Icons.category_outlined;
    }
  }

  Color get color {
    switch (this) {
      case CommunityCategory.suspiciousActivity:
        return const Color(0xFFC62828); // Red
      case CommunityCategory.harassment:
        return const Color(0xFFAD1457); // Deep Pink
      case CommunityCategory.unsafeArea:
        return const Color(0xFFE65100); // Orange
      case CommunityCategory.theft:
        return const Color(0xFF6A1B9A); // Purple
      case CommunityCategory.roadSafety:
        return const Color(0xFF00695C); // Teal
      case CommunityCategory.lostPerson:
        return const Color(0xFF1565C0); // Blue
      case CommunityCategory.helpfulInfo:
        return const Color(0xFF2E7D32); // Green
      case CommunityCategory.other:
        return const Color(0xFF455A64); // Blue Grey
    }
  }

  static CommunityCategory fromString(String? val) {
    if (val == null) return CommunityCategory.other;
    final normalized = val.toUpperCase().trim();
    switch (normalized) {
      case 'SUSPICIOUS_ACTIVITY':
        return CommunityCategory.suspiciousActivity;
      case 'HARASSMENT':
        return CommunityCategory.harassment;
      case 'UNSAFE_AREA':
        return CommunityCategory.unsafeArea;
      case 'THEFT':
        return CommunityCategory.theft;
      case 'ROAD_SAFETY':
        return CommunityCategory.roadSafety;
      case 'LOST_PERSON':
        return CommunityCategory.lostPerson;
      case 'HELPFUL_INFO':
        return CommunityCategory.helpfulInfo;
      default:
        return CommunityCategory.other;
    }
  }
}

class CommunityComment {
  final String id;
  final String content;
  final String authorName;
  final String authorId;
  final DateTime createdAt;
  final bool isOwner;

  CommunityComment({
    required this.id,
    required this.content,
    required this.authorName,
    required this.authorId,
    required this.createdAt,
    this.isOwner = false,
  });

  factory CommunityComment.fromJson(Map<String, dynamic> json) {
    return CommunityComment(
      id: json['id'] as String? ?? '',
      content: json['content'] as String? ?? '',
      authorName: json['authorName'] as String? ?? 'Nirbhay Member',
      authorId: json['authorId'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isOwner: json['isOwner'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'authorName': authorName,
      'authorId': authorId,
      'createdAt': createdAt.toIso8601String(),
      'isOwner': isOwner,
    };
  }
}

class CommunityPost {
  final String id;
  final CommunityCategory category;
  final String title;
  final String description;
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final int upvotesCount;
  final int commentsCount;
  final String authorName;
  final String authorId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final double? distanceKm;
  final bool hasUpvoted;
  final bool isOwner;
  final List<CommunityComment> comments;

  CommunityPost({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    this.locationName,
    this.latitude,
    this.longitude,
    required this.upvotesCount,
    required this.commentsCount,
    required this.authorName,
    required this.authorId,
    required this.createdAt,
    this.updatedAt,
    this.distanceKm,
    this.hasUpvoted = false,
    this.isOwner = false,
    this.comments = const [],
  });

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    List<CommunityComment> parsedComments = [];
    if (json['comments'] is List) {
      parsedComments = (json['comments'] as List)
          .map((c) => CommunityComment.fromJson(c as Map<String, dynamic>))
          .toList();
    }

    return CommunityPost(
      id: json['id'] as String? ?? '',
      category: CommunityCategoryExtension.fromString(json['category'] as String?),
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      locationName: json['locationName'] as String?,
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      upvotesCount: json['upvotesCount'] is int ? json['upvotesCount'] as int : 0,
      commentsCount: json['commentsCount'] is int ? json['commentsCount'] as int : 0,
      authorName: json['authorName'] as String? ?? 'Nirbhay Member',
      authorId: json['authorId'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
      distanceKm: json['distanceKm'] != null ? (json['distanceKm'] as num).toDouble() : null,
      hasUpvoted: json['hasUpvoted'] as bool? ?? false,
      isOwner: json['isOwner'] as bool? ?? false,
      comments: parsedComments,
    );
  }

  CommunityPost copyWith({
    String? id,
    CommunityCategory? category,
    String? title,
    String? description,
    String? locationName,
    double? latitude,
    double? longitude,
    int? upvotesCount,
    int? commentsCount,
    String? authorName,
    String? authorId,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? distanceKm,
    bool? hasUpvoted,
    bool? isOwner,
    List<CommunityComment>? comments,
  }) {
    return CommunityPost(
      id: id ?? this.id,
      category: category ?? this.category,
      title: title ?? this.title,
      description: description ?? this.description,
      locationName: locationName ?? this.locationName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      upvotesCount: upvotesCount ?? this.upvotesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      authorName: authorName ?? this.authorName,
      authorId: authorId ?? this.authorId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      distanceKm: distanceKm ?? this.distanceKm,
      hasUpvoted: hasUpvoted ?? this.hasUpvoted,
      isOwner: isOwner ?? this.isOwner,
      comments: comments ?? this.comments,
    );
  }
}
