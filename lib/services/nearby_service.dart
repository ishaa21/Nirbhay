import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../models/nearby_place_model.dart';
import 'api_config.dart';

enum LocationResultType {
  success,
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled,
  error,
}

class LocationFetchResult {
  final LocationResultType type;
  final Position? position;
  final String? errorMessage;

  const LocationFetchResult({
    required this.type,
    this.position,
    this.errorMessage,
  });
}

class NearbyService {
  static final NearbyService _instance = NearbyService._internal();
  factory NearbyService() => _instance;
  NearbyService._internal();

  /// Safely obtains the user's current GPS location with fallbacks.
  Future<LocationFetchResult> getCurrentLocation() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationFetchResult(
          type: LocationResultType.serviceDisabled,
          errorMessage: 'Location services (GPS) are turned off. Please enable GPS in device settings.',
        );
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return const LocationFetchResult(
            type: LocationResultType.permissionDenied,
            errorMessage: 'Location permission was denied. Nirbhay needs your location to find nearby help.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return const LocationFetchResult(
          type: LocationResultType.permissionDeniedForever,
          errorMessage: 'Location permission is permanently denied. Please grant location access in App Settings.',
        );
      }

      // 1. Try fast cached last-known position
      Position? fallback;
      try {
        fallback = await Geolocator.getLastKnownPosition();
      } catch (_) {}

      // 2. Try fresh high-accuracy position with 5-second timeout
      try {
        final fresh = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );
        return LocationFetchResult(
          type: LocationResultType.success,
          position: fresh,
        );
      } catch (_) {
        if (fallback != null) {
          return LocationFetchResult(
            type: LocationResultType.success,
            position: fallback,
          );
        }
      }

      // 3. Fallback to medium accuracy with 4-second timeout
      try {
        final medium = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 4),
          ),
        );
        return LocationFetchResult(
          type: LocationResultType.success,
          position: medium,
        );
      } catch (_) {
        if (fallback != null) {
          return LocationFetchResult(
            type: LocationResultType.success,
            position: fallback,
          );
        }
      }

      return const LocationFetchResult(
        type: LocationResultType.error,
        errorMessage: 'Could not obtain a GPS fix. Please ensure you are outdoors or near a window.',
      );
    } catch (e) {
      debugPrint('[NearbyService] Location error: $e');
      return LocationFetchResult(
        type: LocationResultType.error,
        errorMessage: 'An unexpected error occurred while accessing location: $e',
      );
    }
  }

  /// Fetches real nearby safety services from Nirbhay backend API.
  Future<Map<String, dynamic>> fetchNearbyPlaces({
    required double lat,
    required double lng,
    String category = 'all',
    int radius = 5000,
    int limit = 20,
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    try {
      final queryParams = {
        'lat': lat.toString(),
        'lng': lng.toString(),
        'category': category,
        'radius': radius.toString(),
        'limit': limit.toString(),
      };

      final uri = Uri.parse('${ApiConfig.baseUrl}/nearby')
          .replace(queryParameters: queryParams);

      final response = await httpClient
          .get(
            uri,
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 12));

      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(response.body);
      } catch (_) {
        return {
          'success': false,
          'message': 'Failed to parse response from server (HTTP ${response.statusCode}).',
        };
      }

      if (response.statusCode == 200 && data['success'] == true) {
        final rawPlaces = (data['places'] as List?) ?? [];
        final places = rawPlaces
            .map((p) => NearbyPlaceModel.fromJson(p as Map<String, dynamic>))
            .toList();

        return {
          'success': true,
          'category': data['category'] ?? category,
          'radius': data['radius'] ?? radius,
          'count': data['count'] ?? places.length,
          'places': places,
          'attribution': data['attribution'] ?? 'Data © OpenStreetMap contributors, ODbL 1.0',
        };
      } else {
        return {
          'success': false,
          'code': data['code'] ?? 'SERVER_ERROR',
          'message': data['message'] ?? 'Failed to load nearby places (HTTP ${response.statusCode}).',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'code': 'TIMEOUT',
        'message': 'Nearby services lookup timed out. Please check your internet connection.',
      };
    } catch (e) {
      return {
        'success': false,
        'code': 'NETWORK_ERROR',
        'message': 'Unable to connect to Nirbhay backend. Please ensure the server is running.',
      };
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }
}
