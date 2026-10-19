import 'package:flutter/material.dart';

class NearbyPlaceModel {
  final String id;
  final String name;
  final String category;
  final double latitude;
  final double longitude;
  final String? address;
  final String? phone;
  final int distanceMeters;
  final String distanceFormatted;
  final String? openingHours;
  final bool? isOpen;

  const NearbyPlaceModel({
    required this.id,
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
    this.address,
    this.phone,
    required this.distanceMeters,
    required this.distanceFormatted,
    this.openingHours,
    this.isOpen,
  });

  factory NearbyPlaceModel.fromJson(Map<String, dynamic> json) {
    return NearbyPlaceModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Emergency Service',
      category: json['category']?.toString() ?? 'other',
      latitude: (json['latitude'] is num) ? (json['latitude'] as num).toDouble() : 0.0,
      longitude: (json['longitude'] is num) ? (json['longitude'] as num).toDouble() : 0.0,
      address: json['address']?.toString(),
      phone: json['phone'] != null && json['phone'].toString().trim().isNotEmpty
          ? json['phone'].toString().trim()
          : null,
      distanceMeters: (json['distanceMeters'] is num) ? (json['distanceMeters'] as num).toInt() : 0,
      distanceFormatted: json['distanceFormatted']?.toString() ?? 'Nearby',
      openingHours: json['openingHours'] != null && json['openingHours'].toString().trim().isNotEmpty
          ? json['openingHours'].toString().trim()
          : null,
      isOpen: json['isOpen'] is bool ? json['isOpen'] as bool : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'phone': phone,
      'distanceMeters': distanceMeters,
      'distanceFormatted': distanceFormatted,
      'openingHours': openingHours,
      'isOpen': isOpen,
    };
  }

  String get categoryDisplayName {
    switch (category.toLowerCase()) {
      case 'police':
        return 'Police Station';
      case 'hospital':
        return 'Hospital / Clinic';
      case 'pharmacy':
        return 'Pharmacy';
      case 'fire_station':
        return 'Fire Station';
      default:
        return 'Safe Zone';
    }
  }

  IconData get categoryIcon {
    switch (category.toLowerCase()) {
      case 'police':
        return Icons.local_police_rounded;
      case 'hospital':
        return Icons.medical_services_rounded;
      case 'pharmacy':
        return Icons.local_pharmacy_rounded;
      case 'fire_station':
        return Icons.local_fire_department_rounded;
      default:
        return Icons.shield_rounded;
    }
  }

  Color get categoryBgColor {
    switch (category.toLowerCase()) {
      case 'police':
        return const Color(0xFF301427).withOpacity(0.12);
      case 'hospital':
        return const Color(0xFF002035).withOpacity(0.12);
      case 'pharmacy':
        return const Color(0xFF059669).withOpacity(0.12);
      case 'fire_station':
        return const Color(0xFFC026D3).withOpacity(0.12);
      default:
        return const Color(0xFF705D67).withOpacity(0.12);
    }
  }

  Color get categoryIconColor {
    switch (category.toLowerCase()) {
      case 'police':
        return const Color(0xFF301427);
      case 'hospital':
        return const Color(0xFF002035);
      case 'pharmacy':
        return const Color(0xFF059669);
      case 'fire_station':
        return const Color(0xFFC026D3);
      default:
        return const Color(0xFF705D67);
    }
  }

  String get displayStatus {
    if (isOpen == true) return 'Open Now';
    if (openingHours != null && openingHours!.isNotEmpty) {
      if (openingHours!.toLowerCase().contains('24/7')) return '24/7 Open';
      return openingHours!;
    }
    return 'Hours Unavailable';
  }

  bool get isVerifiedOpen {
    if (isOpen == true) return true;
    if (openingHours != null && openingHours!.toLowerCase().contains('24/7')) return true;
    return false;
  }
}
