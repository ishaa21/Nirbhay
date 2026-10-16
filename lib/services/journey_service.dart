import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../models/journey_model.dart';
import 'api_config.dart';
import 'auth_service.dart';

class JourneyService {
  static final JourneyService _instance = JourneyService._internal();
  factory JourneyService() => _instance;
  JourneyService._internal();

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<Map<String, String>> _authHeaders() async {
    final token = await AuthService().getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Uri _url(String path) => Uri.parse('${ApiConfig.baseUrl}/journey$path');

  Future<Position?> _tryGetLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) return null;
      }
      if (perm == LocationPermission.deniedForever) return null;

      // Try cached first
      Position? cached;
      try {
        cached = await Geolocator.getLastKnownPosition();
      } catch (_) {}

      // Fresh high-accuracy fix with 5s timeout
      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );
      } catch (_) {
        return cached;
      }
    } catch (e) {
      debugPrint('[JourneyService] Location error: $e');
      return null;
    }
  }

  // ── API Methods ────────────────────────────────────────────────────────────

  /// Start a new live journey session.
  /// Optionally pass [destination] text (e.g. "Home", "Office").
  Future<Map<String, dynamic>> startJourney({
    String? destination,
    bool routeDeviationEnabled = true,
    int deviationThresholdMeters = 150,
  }) async {
    try {
      final headers = await _authHeaders();
      if (!headers.containsKey('Authorization')) {
        return {'success': false, 'message': 'Not authenticated.'};
      }

      final position = await _tryGetLocation();
      final body = <String, dynamic>{
        'routeDeviationEnabled': routeDeviationEnabled,
        'deviationThresholdMeters': deviationThresholdMeters,
        if (destination != null && destination.isNotEmpty)
          'destination': destination,
        if (position != null) 'latitude': position.latitude,
        if (position != null) 'longitude': position.longitude,
      };

      final response = await http
          .post(_url(''), headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 201) {
        return {
          'success': true,
          'journey': JourneyModel.fromJson(data['journey']),
          'trackingUrl': data['trackingUrl'],
          'message': data['message'] ?? 'Journey started.',
          'notifications': data['notifications'],
        };
      } else if (response.statusCode == 409) {
        return {
          'success': false,
          'alreadyActive': true,
          'message': data['message'] ?? 'A journey is already active.',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to start journey (${response.statusCode}).',
        };
      }
    } on TimeoutException {
      return {'success': false, 'message': 'Request timed out.'};
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  /// Fetch the authenticated user's currently active journey.
  Future<Map<String, dynamic>> getActiveJourney() async {
    try {
      final headers = await _authHeaders();
      if (!headers.containsKey('Authorization')) {
        return {'success': false, 'active': false, 'message': 'Not authenticated.'};
      }

      final response = await http
          .get(_url('/active'), headers: headers)
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        final bool active = data['active'] as bool? ?? false;
        return {
          'success': true,
          'active': active,
          'journey': active && data['journey'] != null
              ? JourneyModel.fromJson(data['journey'] as Map<String, dynamic>)
              : null,
        };
      } else {
        return {
          'success': false,
          'active': false,
          'message': data['message'] ?? 'Failed to fetch journey.',
        };
      }
    } on TimeoutException {
      return {'success': false, 'active': false, 'message': 'Timed out.'};
    } catch (e) {
      return {'success': false, 'active': false, 'message': 'Connection error.'};
    }
  }

  /// Upload a GPS breadcrumb for an active journey.
  Future<Map<String, dynamic>> uploadLocation({
    required String journeyId,
    required double latitude,
    required double longitude,
    double? accuracy,
    double? speed,
    double? heading,
  }) async {
    try {
      final headers = await _authHeaders();
      if (!headers.containsKey('Authorization')) {
        return {'success': false, 'message': 'Not authenticated.'};
      }

      final body = <String, dynamic>{
        'latitude': latitude,
        'longitude': longitude,
        if (accuracy != null) 'accuracy': accuracy,
        if (speed != null) 'speed': speed,
        if (heading != null) 'heading': heading,
      };

      final response = await http
          .post(
            _url('/$journeyId/location'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      return {
        'success': response.statusCode == 200,
        'deviationDetected': data['deviationDetected'] ?? false,
        'deviationDistance': data['deviationDistance'],
        'message': data['message'],
      };
    } catch (e) {
      debugPrint('[JourneyService] uploadLocation error: $e');
      return {'success': false, 'message': 'Failed to upload location.'};
    }
  }

  /// End (complete or cancel) a journey.
  Future<Map<String, dynamic>> endJourney({
    required String journeyId,
    String reason = 'COMPLETED', // or 'CANCELLED'
  }) async {
    try {
      final headers = await _authHeaders();
      if (!headers.containsKey('Authorization')) {
        return {'success': false, 'message': 'Not authenticated.'};
      }

      final response = await http
          .patch(
            _url('/$journeyId/end'),
            headers: headers,
            body: jsonEncode({'reason': reason}),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return {
          'success': true,
          'journey': JourneyModel.fromJson(data['journey']),
          'message': data['message'] ?? 'Journey ended.',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to end journey.',
        };
      }
    } on TimeoutException {
      return {'success': false, 'message': 'Request timed out.'};
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  /// Toggle route deviation alarm.
  Future<Map<String, dynamic>> updateDeviationAlarm({
    required String journeyId,
    required bool enabled,
    int? thresholdMeters,
  }) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .patch(
            _url('/$journeyId/deviation-alarm'),
            headers: headers,
            body: jsonEncode({
              'enabled': enabled,
              if (thresholdMeters != null) 'thresholdMeters': thresholdMeters,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': response.statusCode == 200,
        ...data,
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Get the journey history list.
  Future<Map<String, dynamic>> getJourneyHistory() async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(_url('/history'), headers: headers)
          .timeout(const Duration(seconds: 12));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        final List raw = data['journeys'] as List? ?? [];
        return {
          'success': true,
          'journeys': raw
              .map((e) => JourneyModel.fromJson(e as Map<String, dynamic>))
              .toList(),
        };
      }
      return {'success': false, 'message': data['message']};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }
}
