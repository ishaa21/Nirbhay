import 'dart:async';
import 'dart:convert';
// foundation unused
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
  final bool isLastKnown;

  const LocationFetchResult({
    required this.type,
    this.position,
    this.errorMessage,
    this.isLastKnown = false,
  });
}

class NearbyService {
  static final NearbyService _instance = NearbyService._internal();
  factory NearbyService() => _instance;
  NearbyService._internal();

  // Client-side cache for places: `${gridLat}_${gridLng}_${category}_${radius}`
  final Map<String, _CachedPlacesResult> _placesCache = {};
  final Map<String, Future<Map<String, dynamic>>> _inflightPlaces = {};

  // Client-side cache for reverse geocoding: `${gridLat}_${gridLng}`
  final Map<String, _CachedReverseResult> _reverseCache = {};
  final Map<String, Future<Map<String, dynamic>>> _inflightReverse = {};

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
          isLastKnown: false,
        );
      } catch (_) {
        if (fallback != null) {
          return LocationFetchResult(
            type: LocationResultType.success,
            position: fallback,
            isLastKnown: true,
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
          isLastKnown: false,
        );
      } catch (_) {
        if (fallback != null) {
          return LocationFetchResult(
            type: LocationResultType.success,
            position: fallback,
            isLastKnown: true,
          );
        }
      }

      return const LocationFetchResult(
        type: LocationResultType.error,
        errorMessage: 'Unable to acquire satellite GPS fix. Please ensure you have a clear view of the sky.',
      );
    } catch (e) {
      return LocationFetchResult(
        type: LocationResultType.error,
        errorMessage: 'Unexpected location error: $e',
      );
    }
  }

  /// Reverse geocodes coordinates to a human-readable locality / city name.
  /// Uses client-side caching & request deduplication to minimize network calls.
  Future<Map<String, dynamic>> reverseGeocode({
    required double lat,
    required double lng,
    http.Client? client,
  }) async {
    // 300m grid key
    final gridLat = (lat * 300).round() / 300;
    final gridLng = (lng * 300).round() / 300;
    final cacheKey = 'rev_${gridLat}_$gridLng';

    final cached = _reverseCache[cacheKey];
    if (cached != null && DateTime.now().difference(cached.timestamp).inMinutes < 15) {
      return {
        'success': true,
        'cached': true,
        'formattedLocation': cached.formattedLocation,
        'locality': cached.locality,
        'city': cached.city,
        'state': cached.state,
      };
    }

    if (_inflightReverse.containsKey(cacheKey)) {
      return await _inflightReverse[cacheKey]!;
    }

    final future = _executeReverseGeocode(lat, lng, cacheKey, client);
    _inflightReverse[cacheKey] = future;

    try {
      return await future;
    } finally {
      _inflightReverse.remove(cacheKey);
    }
  }

  Future<Map<String, dynamic>> _executeReverseGeocode(
    double lat,
    double lng,
    String cacheKey,
    http.Client? client,
  ) async {
    final httpClient = client ?? http.Client();
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/nearby/reverse')
          .replace(queryParameters: {'lat': lat.toString(), 'lng': lng.toString()});

      final response = await httpClient
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 7));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final formatted = data['formattedLocation']?.toString() ??
              'GPS: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';

          _reverseCache[cacheKey] = _CachedReverseResult(
            timestamp: DateTime.now(),
            formattedLocation: formatted,
            locality: data['locality']?.toString(),
            city: data['city']?.toString(),
            state: data['state']?.toString(),
          );

          return {
            'success': true,
            'cached': false,
            'formattedLocation': formatted,
            'locality': data['locality']?.toString(),
            'city': data['city']?.toString(),
            'state': data['state']?.toString(),
          };
        }
      }

      // Fallback coordinate representation if upstream returned error
      final fallbackFormatted = 'GPS: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
      return {
        'success': true,
        'cached': false,
        'isFallback': true,
        'formattedLocation': fallbackFormatted,
      };
    } catch (_) {
      final fallbackFormatted = 'GPS: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
      return {
        'success': true,
        'cached': false,
        'isFallback': true,
        'formattedLocation': fallbackFormatted,
      };
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// Fetches real nearby safety services from Nirbhay backend API.
  /// Features client-side in-flight deduplication and category caching.
  Future<Map<String, dynamic>> fetchNearbyPlaces({
    required double lat,
    required double lng,
    String category = 'all',
    int radius = 5000,
    int limit = 20,
    bool forceRefresh = false,
    http.Client? client,
  }) async {
    final gridLat = (lat * 300).round() / 300;
    final gridLng = (lng * 300).round() / 300;
    final cacheKey = '${gridLat}_${gridLng}_${category}_$radius';

    if (!forceRefresh) {
      final cached = _placesCache[cacheKey];
      if (cached != null && DateTime.now().difference(cached.timestamp).inMinutes < 5) {
        return {
          'success': true,
          'cached': true,
          'category': category,
          'radius': radius,
          'count': cached.places.length,
          'places': cached.places,
          'attribution': cached.attribution,
        };
      }
    }

    if (_inflightPlaces.containsKey(cacheKey)) {
      return await _inflightPlaces[cacheKey]!;
    }

    final future = _executeFetchNearbyPlaces(
      lat: lat,
      lng: lng,
      category: category,
      radius: radius,
      limit: limit,
      cacheKey: cacheKey,
      client: client,
    );
    _inflightPlaces[cacheKey] = future;

    try {
      return await future;
    } finally {
      _inflightPlaces.remove(cacheKey);
    }
  }

  Future<Map<String, dynamic>> _executeFetchNearbyPlaces({
    required double lat,
    required double lng,
    required String category,
    required int radius,
    required int limit,
    required String cacheKey,
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

        final attribution = data['attribution']?.toString() ??
            'Data © OpenStreetMap contributors, ODbL 1.0';

        _placesCache[cacheKey] = _CachedPlacesResult(
          timestamp: DateTime.now(),
          places: places,
          attribution: attribution,
        );

        return {
          'success': true,
          'cached': data['cached'] == true,
          'category': data['category'] ?? category,
          'radius': data['radius'] ?? radius,
          'count': data['count'] ?? places.length,
          'places': places,
          'attribution': attribution,
        };
      } else if (response.statusCode == 429) {
        return {
          'success': false,
          'code': 'RATE_LIMITED',
          'message': data['message'] ?? 'Rate limit reached. Please wait a moment before trying again.',
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

  void clearCache() {
    _placesCache.clear();
    _reverseCache.clear();
  }
}

class _CachedPlacesResult {
  final DateTime timestamp;
  final List<NearbyPlaceModel> places;
  final String attribution;

  _CachedPlacesResult({
    required this.timestamp,
    required this.places,
    required this.attribution,
  });
}

class _CachedReverseResult {
  final DateTime timestamp;
  final String formattedLocation;
  final String? locality;
  final String? city;
  final String? state;

  _CachedReverseResult({
    required this.timestamp,
    required this.formattedLocation,
    this.locality,
    this.city,
    this.state,
  });
}
