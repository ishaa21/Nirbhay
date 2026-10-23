import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../models/sos_model.dart';
import 'api_config.dart';
import 'auth_service.dart';
import 'contact_service.dart';
import 'location_update_service.dart';
import 'sos_sms_dispatcher.dart';

/// Encapsulates the location fix for an emergency SOS.
class SosLocationResult {
  final double? latitude;
  final double? longitude;
  final bool isLastKnown;
  final DateTime? timestamp;

  const SosLocationResult({
    this.latitude,
    this.longitude,
    this.isLastKnown = false,
    this.timestamp,
  });

  bool get hasCoordinates => latitude != null && longitude != null;

  String? get formattedTimestamp {
    if (timestamp == null) return null;
    return timestamp!.toLocal().toString().split('.')[0];
  }
}

class SosService {
  static final SosService _instance = SosService._internal();
  factory SosService() => _instance;
  SosService._internal();

  static const String _lastLocationKey = 'nirbhay_last_gps_fix';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  SosIncidentModel? _activeOfflineIncident;

  /// Returns current active offline incident if present
  SosIncidentModel? get activeOfflineIncident => _activeOfflineIncident;

  /// Clear active offline incident
  void clearActiveOfflineIncident() {
    _activeOfflineIncident = null;
  }

  /// Store any location fix persistently so it's available as fallback
  static Future<void> cacheLocationFix(
    double latitude,
    double longitude,
    DateTime timestamp,
  ) async {
    try {
      const storage = FlutterSecureStorage();
      final data = jsonEncode({
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': timestamp.toIso8601String(),
      });
      await storage.write(key: _lastLocationKey, value: data);
    } catch (e) {
      debugPrint('[SOS Location] Failed to persist last location: $e');
    }
  }

  Future<SosLocationResult> _getPersistedFallbackLocation() async {
    try {
      final raw = await _storage.read(key: _lastLocationKey);
      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final lat = double.tryParse(map['latitude'].toString());
        final lng = double.tryParse(map['longitude'].toString());
        final tsStr = map['timestamp']?.toString();
        final ts = tsStr != null ? DateTime.tryParse(tsStr) : null;
        if (lat != null && lng != null) {
          return SosLocationResult(
            latitude: lat,
            longitude: lng,
            isLastKnown: true,
            timestamp: ts,
          );
        }
      }
    } catch (_) {}
    return const SosLocationResult(
      latitude: null,
      longitude: null,
      isLastKnown: false,
      timestamp: null,
    );
  }

  /// Acquire freshest GPS coordinates within bounded timeout (default 4s),
  /// falling back to last-known coordinates with timestamp, or null without blocking alert.
  Future<SosLocationResult> getSosLocation({
    Duration freshTimeout = const Duration(seconds: 4),
  }) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[SOS Location] GPS service disabled. Using stored fallback.');
        return await _getPersistedFallbackLocation();
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('[SOS Location] Location permission denied. Using stored fallback.');
        return await _getPersistedFallbackLocation();
      }

      // Read last-known position immediately as instant candidate
      Position? cachedPosition;
      try {
        cachedPosition = await Geolocator.getLastKnownPosition();
      } catch (_) {}

      // Attempt fresh high-accuracy GPS fix with bounded timeout
      try {
        final fresh = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: freshTimeout,
          ),
        );
        final ts = fresh.timestamp;
        cacheLocationFix(fresh.latitude, fresh.longitude, ts);
        return SosLocationResult(
          latitude: fresh.latitude,
          longitude: fresh.longitude,
          isLastKnown: false,
          timestamp: ts,
        );
      } catch (e) {
        debugPrint('[SOS Location] Fresh GPS timed out ($e). Falling back to last known location.');
      }

      if (cachedPosition != null) {
        final ts = cachedPosition.timestamp;
        cacheLocationFix(cachedPosition.latitude, cachedPosition.longitude, ts);
        return SosLocationResult(
          latitude: cachedPosition.latitude,
          longitude: cachedPosition.longitude,
          isLastKnown: true,
          timestamp: ts,
        );
      }

      return await _getPersistedFallbackLocation();
    } catch (e) {
      debugPrint('[SOS Location] Error in getSosLocation: $e');
      return await _getPersistedFallbackLocation();
    }
  }

  /// Build standard SOS alert SMS body.
  /// Includes fresh coordinates or LAST KNOWN LOCATION with timestamp, or Location: Unavailable.
  static String buildAlertMessage({
    required DateTime activatedAt,
    SosLocationResult? location,
    String? trackingUrl,
  }) {
    final timeStr = activatedAt.toLocal().toString().split('.')[0];
    String locationStr;
    if (location != null && location.hasCoordinates) {
      final lat = location.latitude!;
      final lng = location.longitude!;
      final latStr = lat.toStringAsFixed(4);
      final lngStr = lng.toStringAsFixed(4);
      final mapsUrl = 'https://maps.google.com/?q=$lat,$lng';
      if (location.isLastKnown) {
        final locTime = location.formattedTimestamp;
        final timeSuffix = locTime != null ? ' as of $locTime' : '';
        locationStr = 'Location: $mapsUrl ($latStr, $lngStr) [LAST KNOWN LOCATION$timeSuffix]';
      } else {
        locationStr = 'Location: $mapsUrl ($latStr, $lngStr)';
      }
    } else {
      locationStr = 'Location: Unavailable';
    }

    final trackingStr = (trackingUrl != null && trackingUrl.isNotEmpty)
        ? ' Live Tracking: $trackingUrl'
        : '';

    return 'EMERGENCY ALERT: Nirbhay SOS activated at $timeStr. $locationStr.$trackingStr Please check immediately.';
  }

  /// Create / Activate an SOS incident.
  /// Dispatches direct Android SIM SMS without internet dependency,
  /// and runs backend incident registration independently.
  Future<Map<String, dynamic>> createSos() async {
    try {
      // 1. Deduplication: check if an active incident already exists locally
      if (_activeOfflineIncident != null && _activeOfflineIncident!.isActive) {
        return {
          'success': false,
          'alreadyActive': true,
          'incident': _activeOfflineIncident,
          'message': 'An active SOS incident is already in progress.',
        };
      }

      final now = DateTime.now();
      final localIncidentId = 'offline_sos_${now.millisecondsSinceEpoch}';

      // 2. Acquire freshest GPS coordinates with bounded 4s timeout
      final locationResult = await getSosLocation();

      // 3. Fetch emergency contacts (falls back to local cache if offline)
      final contacts = await EmergencyContactService().getLocalContacts();
      final alertContacts = contacts.where((c) => c.autoAlert).toList();
      final targetContacts = alertContacts.isNotEmpty ? alertContacts : contacts;

      // 4. Construct SMS message body
      final messageBody = buildAlertMessage(
        activatedAt: now,
        location: locationResult,
      );

      // 5. Send emergency SMS immediately via native SIM SMS (NO backend prerequisite)
      Map<String, dynamic>? smsDispatchResult;
      if (targetContacts.isNotEmpty) {
        try {
          smsDispatchResult = await SosSmsDispatcher().dispatchDirectSms(
            sosId: localIncidentId,
            contacts: targetContacts,
            messageBody: messageBody,
          );
        } catch (smsErr) {
          debugPrint('[SOS Service] Direct SIM SMS dispatch error: $smsErr');
        }
      }

      final localIncident = SosIncidentModel(
        id: localIncidentId,
        userId: '',
        status: 'ACTIVE',
        latitude: locationResult.latitude,
        longitude: locationResult.longitude,
        activatedAt: now,
        notificationStatus: (smsDispatchResult?['success'] == true) ? 'SENT' : 'PENDING',
      );
      _activeOfflineIncident = localIncident;

      // Start continuous GPS tracking automatically
      LocationUpdateService().start(sosId: localIncident.id);

      // 6. Independent backend incident registration (Requirement 7)
      final token = await AuthService().getToken();
      if (token == null || token.isEmpty) {
        return {
          'success': true,
          'incident': localIncident,
          'offline': true,
          'smsDispatched': smsDispatchResult?['success'] == true,
          'message': 'SOS alert activated offline. Emergency SMS sent to contacts.',
        };
      }

      try {
        final url = Uri.parse('${ApiConfig.baseUrl}/sos');
        final Map<String, dynamic> requestBody = {};
        if (locationResult.latitude != null && locationResult.longitude != null) {
          requestBody['latitude'] = locationResult.latitude;
          requestBody['longitude'] = locationResult.longitude;
        }

        final response = await http
            .post(
              url,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode(requestBody),
            )
            .timeout(const Duration(seconds: 8));

        final data = jsonDecode(response.body);

        if (response.statusCode == 201) {
          final serverIncident = SosIncidentModel.fromJson(data['incident']);
          _activeOfflineIncident = serverIncident;

          // Link local session to backend incident to prevent duplicate SMS
          SosSmsDispatcher().linkIncidents(localIncidentId, serverIncident.id);

          // Update LocationUpdateService to track server incident ID
          LocationUpdateService().start(sosId: serverIncident.id);

          final deviceSms = data['deviceSms'] as Map<String, dynamic>?;
          if (deviceSms != null) {
            // SosSmsDispatcher recognizes serverIncident.id as already dispatched,
            // reports sent status to backend, and skips duplicate SMS transmission
            SosSmsDispatcher().dispatchDeviceSmsPayload(
              sosId: serverIncident.id,
              deviceSms: deviceSms,
            );
          }

          return {
            'success': true,
            'incident': serverIncident,
            'message': data['message'] ?? 'SOS incident activated.',
            'notifications': data['notifications'],
            'deviceSms': deviceSms,
            'smsDispatched': true,
          };
        } else if (response.statusCode == 409) {
          final serverIncident = data['incident'] != null
              ? SosIncidentModel.fromJson(data['incident'])
              : null;
          if (serverIncident != null) {
            _activeOfflineIncident = serverIncident;
            LocationUpdateService().start(sosId: serverIncident.id);
          }
          return {
            'success': false,
            'alreadyActive': true,
            'incident': serverIncident ?? localIncident,
            'message': data['message'] ?? 'An active SOS incident is already in progress.',
          };
        }
      } on SocketException catch (_) {
        debugPrint('[SOS Service] Backend offline. Direct SMS was dispatched.');
      } on TimeoutException catch (_) {
        debugPrint('[SOS Service] Backend timed out. Direct SMS was dispatched.');
      } catch (netErr) {
        debugPrint('[SOS Service] Backend registration error: $netErr');
      }

      // When backend is unreachable, the offline incident remains active with direct SMS dispatched
      return {
        'success': true,
        'incident': localIncident,
        'offline': true,
        'smsDispatched': smsDispatchResult?['success'] == true,
        'message': 'SOS alert activated offline. Emergency SMS sent to contacts.',
      };
    } catch (e) {
      debugPrint('[SOS Service] Exception in createSos: $e');
      return {
        'success': false,
        'message': 'Failed to trigger SOS alert ($e).',
      };
    }
  }

  /// Synchronize pending offline SOS incident with backend when connectivity is restored
  Future<void> syncPendingOfflineSos() async {
    if (_activeOfflineIncident == null || !_activeOfflineIncident!.id.startsWith('offline_')) {
      return;
    }

    try {
      final token = await AuthService().getToken();
      if (token == null || token.isEmpty) return;

      final incident = _activeOfflineIncident!;
      final url = Uri.parse('${ApiConfig.baseUrl}/sos');
      final Map<String, dynamic> requestBody = {};
      if (incident.latitude != null && incident.longitude != null) {
        requestBody['latitude'] = incident.latitude;
        requestBody['longitude'] = incident.longitude;
      }

      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 201 || response.statusCode == 409) {
        final serverData = data['incident'];
        if (serverData != null) {
          final serverIncident = SosIncidentModel.fromJson(serverData);
          SosSmsDispatcher().linkIncidents(incident.id, serverIncident.id);
          _activeOfflineIncident = serverIncident;
          LocationUpdateService().start(sosId: serverIncident.id);

          final deviceSms = data['deviceSms'] as Map<String, dynamic>?;
          if (deviceSms != null) {
            SosSmsDispatcher().dispatchDeviceSmsPayload(
              sosId: serverIncident.id,
              deviceSms: deviceSms,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[SOS Service] syncPendingOfflineSos error: $e');
    }
  }

  /// Fetch user's active SOS incident if one exists
  Future<Map<String, dynamic>> getActiveSos() async {
    if (_activeOfflineIncident != null && _activeOfflineIncident!.isActive) {
      return {
        'success': true,
        'active': true,
        'incident': _activeOfflineIncident,
        'notifications': <SosNotificationModel>[],
        'offline': true,
      };
    }

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

        if (incident != null && active) {
          _activeOfflineIncident = incident;
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
    _activeOfflineIncident = null;
    LocationUpdateService().stop();

    final isOfflineIncident = incidentId.startsWith('offline_');
    const resolveMsg =
        'STATUS UPDATE: Nirbhay SOS emergency alert has been RESOLVED. User is SAFE now. No further action is required.';

    if (isOfflineIncident) {
      final contacts = await EmergencyContactService().getLocalContacts();
      final alertContacts = contacts.where((c) => c.autoAlert).toList();
      final targetContacts = alertContacts.isNotEmpty ? alertContacts : contacts;

      if (targetContacts.isNotEmpty) {
        try {
          await SosSmsDispatcher().dispatchDirectSms(
            sosId: '${incidentId}_resolved',
            contacts: targetContacts,
            messageBody: resolveMsg,
          );
        } catch (_) {}
      }

      return {
        'success': true,
        'message': 'SOS resolved. "User is safe" SMS sent to emergency contacts.',
      };
    }

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
      // If network fails while resolving online incident, dispatch "User is safe" SMS directly
      final contacts = await EmergencyContactService().getLocalContacts();
      final alertContacts = contacts.where((c) => c.autoAlert).toList();
      final targetContacts = alertContacts.isNotEmpty ? alertContacts : contacts;

      if (targetContacts.isNotEmpty) {
        try {
          await SosSmsDispatcher().dispatchDirectSms(
            sosId: '${incidentId}_resolved',
            contacts: targetContacts,
            messageBody: resolveMsg,
          );
        } catch (_) {}
      }

      return {
        'success': true,
        'message': 'SOS resolved offline. "User is safe" SMS sent to emergency contacts.',
      };
    }
  }

  /// Cancel an active SOS incident
  Future<Map<String, dynamic>> cancelSos(String incidentId) async {
    _activeOfflineIncident = null;
    LocationUpdateService().stop();

    if (incidentId.startsWith('offline_')) {
      return {
        'success': true,
        'message': 'SOS incident cancelled.',
      };
    }

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
      return {
        'success': true,
        'message': 'SOS incident cancelled locally.',
      };
    }
  }
}
