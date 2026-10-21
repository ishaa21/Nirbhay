import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../models/safety_timer_model.dart';
import 'api_config.dart';
import 'auth_service.dart';

/// Service for all Safety Timer API calls.
/// Mirrors the patterns used by SosService.
class SafetyTimerService {
  static final SafetyTimerService _instance = SafetyTimerService._internal();
  factory SafetyTimerService() => _instance;
  SafetyTimerService._internal();

  // ── Location helper (reuses geolocator, same pattern as SosService) ────────
  Future<Position?> tryGetLocation() async {
    try {
      bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) return null;
      }
      if (perm == LocationPermission.deniedForever) return null;

      // Fast: try cached last-known first
      Position? last;
      try {
        last = await Geolocator.getLastKnownPosition();
      } catch (_) {}

      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 4),
          ),
        );
      } catch (_) {
        return last;
      }
    } catch (e) {
      debugPrint('[TimerService] tryGetLocation error: $e');
      return null;
    }
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await AuthService().getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // ── API calls ───────────────────────────────────────────────────────────────

  /// Start a new safety timer for the given duration (5, 15, 30, or 60 minutes).
  Future<Map<String, dynamic>> startTimer(int durationMinutes) async {
    try {
      final token = await AuthService().getToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'sessionExpired': true, 'message': 'Not authenticated. Please log in.'};
      }

      final position = await tryGetLocation();
      final body = <String, dynamic>{'durationMinutes': durationMinutes};
      if (position != null) {
        body['latitude'] = position.latitude;
        body['longitude'] = position.longitude;
      }

      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/timer'),
        headers: await _authHeaders(),
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

      Map<String, dynamic> data = {};
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      } catch (_) {
        if (res.statusCode == 404) {
          return {
            'success': false,
            'message': 'Timer API not found on server (404). Please ensure the latest backend is deployed.',
          };
        }
        return {
          'success': false,
          'message': 'Server returned an invalid response (HTTP ${res.statusCode}).',
        };
      }

      if (res.statusCode == 201) {
        return {
          'success': true,
          'timer': SafetyTimerModel.fromJson(data['timer']),
          'message': data['message'],
        };
      } else if (res.statusCode == 409) {
        return {
          'success': false,
          'alreadyActive': true,
          'timerId': data['timerId'],
          'message': data['message'],
        };
      } else if (res.statusCode == 401 || res.statusCode == 403) {
        return {
          'success': false,
          'sessionExpired': true,
          'message': 'Your session has expired. Please sign in again.',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to start timer (HTTP ${res.statusCode}).',
        };
      }
    } on SocketException {
      return {'success': false, 'offline': true, 'message': 'No internet connection. Automatic server timer requires connectivity to initiate.'};
    } on TimeoutException {
      return {'success': false, 'offline': true, 'message': 'Connection timed out. Check your mobile network or Wi-Fi.'};
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  /// Fetch the user's current active timer, if any.
  Future<Map<String, dynamic>> getActiveTimer() async {
    try {
      final token = await AuthService().getToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'active': false, 'message': 'Not authenticated.'};
      }

      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/timer/active'),
        headers: await _authHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 401 || res.statusCode == 403) {
        return {'success': false, 'sessionExpired': true, 'active': false, 'message': 'Session expired.'};
      }

      Map<String, dynamic> data = {};
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      } catch (_) {
        return {'success': false, 'active': false, 'message': 'Invalid response from server (HTTP ${res.statusCode}).'};
      }

      if (res.statusCode == 200) {
        final active = data['active'] == true;
        final timer = active ? SafetyTimerModel.fromJson(data['timer']) : null;
        return {
          'success': true,
          'active': active,
          'timer': timer,
          'remainingMs': data['remainingMs'],
        };
      } else {
        return {'success': false, 'active': false, 'message': data['message'] ?? 'Failed to fetch timer.'};
      }
    } on SocketException {
      return {'success': false, 'offline': true, 'active': false, 'message': 'Device is currently offline.'};
    } on TimeoutException {
      return {'success': false, 'offline': true, 'active': false, 'message': 'Request timed out.'};
    } catch (e) {
      return {'success': false, 'active': false, 'message': 'Connection error.'};
    }
  }

  /// Check in — marks the user as safe and stops the timer.
  Future<Map<String, dynamic>> checkIn(String timerId) async {
    try {
      final token = await AuthService().getToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'sessionExpired': true, 'message': 'Session expired. Please log in.'};
      }

      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/timer/$timerId/checkin'),
        headers: await _authHeaders(),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 401 || res.statusCode == 403) {
        return {'success': false, 'sessionExpired': true, 'message': 'Session expired. Please sign in again.'};
      }

      Map<String, dynamic> data = {};
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      } catch (_) {
        return {'success': false, 'message': 'Invalid server response (HTTP ${res.statusCode}).'};
      }

      if (res.statusCode == 200) {
        return {
          'success': true,
          'timer': SafetyTimerModel.fromJson(data['timer']),
          'message': data['message'],
        };
      } else {
        return {'success': false, 'message': data['message'] ?? 'Check-in failed.'};
      }
    } on SocketException {
      return {'success': false, 'offline': true, 'message': 'Offline: Unable to contact server. Please connect to the internet to check in and avoid alert dispatch.'};
    } on TimeoutException {
      return {'success': false, 'offline': true, 'message': 'Request timed out during check-in.'};
    } catch (e) {
      return {'success': false, 'message': 'Connection error during check-in: $e'};
    }
  }

  /// Cancel the timer without alerting anyone.
  Future<Map<String, dynamic>> cancelTimer(String timerId) async {
    try {
      final token = await AuthService().getToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'sessionExpired': true, 'message': 'Session expired. Please log in.'};
      }

      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/timer/$timerId/cancel'),
        headers: await _authHeaders(),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 401 || res.statusCode == 403) {
        return {'success': false, 'sessionExpired': true, 'message': 'Session expired. Please sign in again.'};
      }

      Map<String, dynamic> data = {};
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      } catch (_) {
        return {'success': false, 'message': 'Invalid server response (HTTP ${res.statusCode}).'};
      }

      if (res.statusCode == 200) {
        return {
          'success': true,
          'timer': SafetyTimerModel.fromJson(data['timer']),
          'message': data['message'],
        };
      } else {
        return {'success': false, 'message': data['message'] ?? 'Cancel failed.'};
      }
    } on SocketException {
      return {'success': false, 'offline': true, 'message': 'Offline: Unable to reach server to cancel timer.'};
    } on TimeoutException {
      return {'success': false, 'offline': true, 'message': 'Request timed out during cancel.'};
    } catch (e) {
      return {'success': false, 'message': 'Connection error during cancel: $e'};
    }
  }

  /// Extend an active timer by [extendMinutes] (5, 15, 30, or 60).
  Future<Map<String, dynamic>> extendTimer(String timerId, int extendMinutes) async {
    try {
      final token = await AuthService().getToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'sessionExpired': true, 'message': 'Session expired. Please log in.'};
      }

      final position = await tryGetLocation();
      final body = <String, dynamic>{'extendMinutes': extendMinutes};
      if (position != null) {
        body['latitude'] = position.latitude;
        body['longitude'] = position.longitude;
      }

      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/timer/$timerId/extend'),
        headers: await _authHeaders(),
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 401 || res.statusCode == 403) {
        return {'success': false, 'sessionExpired': true, 'message': 'Session expired. Please sign in again.'};
      }

      Map<String, dynamic> data = {};
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      } catch (_) {
        return {'success': false, 'message': 'Invalid server response (HTTP ${res.statusCode}).'};
      }

      if (res.statusCode == 200) {
        return {
          'success': true,
          'timer': SafetyTimerModel.fromJson(data['timer']),
          'message': data['message'],
        };
      } else {
        return {'success': false, 'message': data['message'] ?? 'Extend failed.'};
      }
    } on SocketException {
      return {'success': false, 'offline': true, 'message': 'Offline: Unable to contact server to extend timer.'};
    } on TimeoutException {
      return {'success': false, 'offline': true, 'message': 'Request timed out during extend.'};
    } catch (e) {
      return {'success': false, 'message': 'Connection error during extend: $e'};
    }
  }

  /// Update last known GPS location on the active timer.
  Future<Map<String, dynamic>> updateLocation(String timerId, double latitude, double longitude) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/timer/$timerId/location'),
        headers: await _authHeaders(),
        body: jsonEncode({'latitude': latitude, 'longitude': longitude}),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200) {
        return {'success': true, 'timer': SafetyTimerModel.fromJson(data['timer'])};
      }
      return {'success': false, 'message': data['message'] ?? 'Failed to update location.'};
    } catch (e) {
      return {'success': false, 'message': 'Error updating location: $e'};
    }
  }
}
