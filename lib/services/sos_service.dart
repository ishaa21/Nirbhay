import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../models/sos_model.dart';
import 'api_config.dart';
import 'auth_service.dart';
import 'location_update_service.dart';
import 'sos_sms_dispatcher.dart';

class SosService {
  static final SosService _instance = SosService._internal();
  factory SosService() => _instance;
  SosService._internal();

  /// Safely attempt to fetch current location without blocking or crashing
  Future<Position?> _tryGetLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[SOS Location] Device location service (GPS) is disabled.');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('[SOS Location] Location permission was denied by user.');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('[SOS Location] Location permission is denied forever in app settings.');
        return null;
      }

      // 1. Immediately fetch cached last known position as instant fallback
      Position? fallbackPosition;
      try {
        fallbackPosition = await Geolocator.getLastKnownPosition();
        if (fallbackPosition != null) {
          debugPrint('[SOS Location] Last known position cached: ${fallbackPosition.latitude}, ${fallbackPosition.longitude}');
        }
      } catch (err) {
        debugPrint('[SOS Location] Could not read last known position: $err');
      }

      // 2. Attempt fresh position fix with balanced/high accuracy and 5s timeout
      try {
        final freshPosition = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );
        debugPrint('[SOS Location] Acquired fresh position: ${freshPosition.latitude}, ${freshPosition.longitude}');
        return freshPosition;
      } catch (freshErr) {
        debugPrint('[SOS Location] Fresh high-accuracy location timed out ($freshErr). Falling back...');
        if (fallbackPosition != null) {
          return fallbackPosition;
        }
      }

      // 3. If no cached position and high accuracy timed out, try medium accuracy with 3s timeout
      try {
        final mediumPosition = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 3),
          ),
        );
        debugPrint('[SOS Location] Acquired medium-accuracy position: ${mediumPosition.latitude}, ${mediumPosition.longitude}');
        return mediumPosition;
      } catch (_) {
        return fallbackPosition;
      }
    } catch (e) {
      debugPrint('[SOS Location] Exception in _tryGetLocation: $e');
      return null;
    }
  }

  /// Create / Activate an SOS incident
  Future<Map<String, dynamic>> createSos() async {
    try {
      final token = await AuthService().getToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'message': 'Not authenticated. Please log in.'};
      }

      // Fetch location non-blocking (max 4 second timeout)
      final position = await _tryGetLocation();

      final url = Uri.parse('${ApiConfig.baseUrl}/sos');
      final Map<String, dynamic> requestBody = {};
      if (position != null) {
        requestBody['latitude'] = position.latitude;
        requestBody['longitude'] = position.longitude;
      }

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 15));

      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(response.body);
      } catch (_) {
        return {
          'success': false,
          'message': 'Backend response error (${response.statusCode}). Please ensure local backend is running or backend is deployed on Render.',
        };
      }

      if (response.statusCode == 201) {
        final incident = SosIncidentModel.fromJson(data['incident']);
        final deviceSms = data['deviceSms'] as Map<String, dynamic>?;
        // Start live continuous GPS tracking automatically
        LocationUpdateService().start(sosId: incident.id);
        // Fire-and-forget: native SMS from this device (does not block SOS activation UI).
        SosSmsDispatcher().dispatchDeviceSmsPayload(
          sosId: incident.id,
          deviceSms: deviceSms,
        );
        return {
          'success': true,
          'incident': incident,
          'message': data['message'] ?? 'SOS incident activated.',
          'notifications': data['notifications'],
          'deviceSms': deviceSms,
        };
      } else if (response.statusCode == 409) {
        // Active incident already exists — ensure tracking is active
        final incident = data['incident'] != null 
            ? SosIncidentModel.fromJson(data['incident'])
            : null;
        if (incident != null) {
          LocationUpdateService().start(sosId: incident.id);
        }
        return {
          'success': false,
          'alreadyActive': true,
          'incident': incident,
          'message': data['message'] ?? 'An active SOS incident is already in progress.',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to activate SOS emergency alert (HTTP ${response.statusCode}).',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'message': 'Request timed out. Please check your network connection.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: Unable to reach backend server ($e).',
      };
    }
  }


  /// Fetch user's active SOS incident if one exists
  Future<Map<String, dynamic>> getActiveSos() async {
    try {
      final token = await AuthService().getToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'message': 'Not authenticated. Please log in.'};
      }

      final url = Uri.parse('${ApiConfig.baseUrl}/sos/active');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final bool active = data['active'] ?? false;
        final incident = data['incident'] != null 
            ? SosIncidentModel.fromJson(data['incident']) 
            : null;
        final List rawLogs = data['notifications'] ?? [];
        final notifications = rawLogs.map((e) => SosNotificationModel.fromJson(e)).toList();

        final deviceSms = data['deviceSms'] as Map<String, dynamic>?;
        if (active && incident != null && deviceSms != null) {
          SosSmsDispatcher().dispatchDeviceSmsPayload(
            sosId: incident.id,
            deviceSms: deviceSms,
          );
        }

        return {
          'success': true,
          'active': active,
          'incident': incident,
          'notifications': notifications,
          'deviceSms': deviceSms,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch active SOS status.',
        };
      }
    } on TimeoutException {
      return {'success': false, 'message': 'Request timed out.'};
    } catch (e) {
      return {'success': false, 'message': 'Connection error.'};
    }
  }

  /// Fetch user's SOS incident history
  Future<Map<String, dynamic>> getSosHistory() async {
    try {
      final token = await AuthService().getToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'message': 'Not authenticated.'};
      }

      final url = Uri.parse('${ApiConfig.baseUrl}/sos/history');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 12));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final List rawList = data['incidents'] ?? [];
        final incidents = rawList.map((e) => SosIncidentModel.fromJson(e)).toList();
        return {'success': true, 'incidents': incidents};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to fetch history.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error.'};
    }
  }

  /// Resolve an active SOS incident
  Future<Map<String, dynamic>> resolveSos(String incidentId) async {
    try {
      final token = await AuthService().getToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'message': 'Not authenticated.'};
      }

      final url = Uri.parse('${ApiConfig.baseUrl}/sos/$incidentId/resolve');
      final response = await http.patch(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final incident = SosIncidentModel.fromJson(data['incident']);
        final deviceSms = data['deviceSms'] as Map<String, dynamic>?;
        LocationUpdateService().stop();
        SosSmsDispatcher().dispatchDeviceSmsPayload(
          sosId: incident.id,
          deviceSms: deviceSms,
        );
        return {
          'success': true,
          'incident': incident,
          'message': data['message'] ?? 'SOS incident resolved.',
          'deviceSms': deviceSms,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to resolve SOS incident.',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error while resolving SOS.'};
    }
  }

  /// Cancel an active SOS incident
  Future<Map<String, dynamic>> cancelSos(String incidentId) async {
    try {
      final token = await AuthService().getToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'message': 'Not authenticated.'};
      }

      final url = Uri.parse('${ApiConfig.baseUrl}/sos/$incidentId/cancel');
      final response = await http.patch(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final incident = SosIncidentModel.fromJson(data['incident']);
        LocationUpdateService().stop();
        return {
          'success': true,
          'incident': incident,
          'message': data['message'] ?? 'SOS incident cancelled.',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to cancel SOS incident.',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error while cancelling SOS.'};
    }
  }
}
