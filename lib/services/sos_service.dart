import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../models/sos_model.dart';
import 'api_config.dart';
import 'auth_service.dart';

class SosService {
  static final SosService _instance = SosService._internal();
  factory SosService() => _instance;
  SosService._internal();

  /// Safely attempt to fetch current location without blocking or crashing
  Future<Position?> _tryGetLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      // Fetch position with 4-second timeout to prevent blocking SOS activation
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      // Return null on location failure or timeout
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
        return {
          'success': true,
          'incident': incident,
          'message': data['message'] ?? 'SOS incident activated.',
          'notifications': data['notifications'],
        };
      } else if (response.statusCode == 409) {
        // Active incident already exists
        final incident = data['incident'] != null 
            ? SosIncidentModel.fromJson(data['incident'])
            : null;
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

        return {
          'success': true,
          'active': active,
          'incident': incident,
          'notifications': notifications,
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
        return {
          'success': true,
          'incident': incident,
          'message': data['message'] ?? 'SOS incident resolved.',
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
