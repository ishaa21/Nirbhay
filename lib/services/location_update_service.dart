import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_service.dart';

/// Manages periodic GPS location uploads to the backend while an SOS is active.
/// Call [start] when SOS activates and [stop] when it resolves/cancels.
class LocationUpdateService {
  static final LocationUpdateService _instance = LocationUpdateService._internal();
  factory LocationUpdateService() => _instance;
  LocationUpdateService._internal();

  Timer? _timer;
  String? _activeSosId;
  bool _isRunning = false;

  /// How often to upload a fresh GPS fix (every 15 seconds)
  static const Duration _uploadInterval = Duration(seconds: 15);

  bool get isRunning => _isRunning;
  String? get activeSosId => _activeSosId;

  /// Start periodic location uploads for the given [sosId].
  /// Immediately uploads the first fix, then every [_uploadInterval].
  void start(String sosId) {
    if (_isRunning && _activeSosId == sosId) {
      debugPrint('[LocationUpdateService] Already tracking SOS $sosId — skipping duplicate start.');
      return;
    }

    // Stop any previous tracking session first
    stop();

    _activeSosId = sosId;
    _isRunning = true;
    debugPrint('[LocationUpdateService] Starting periodic location tracking for SOS $sosId.');

    // Upload immediately, then on interval
    _uploadLocation();
    _timer = Timer.periodic(_uploadInterval, (_) => _uploadLocation());
  }

  /// Stop periodic location uploads.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    final prevId = _activeSosId;
    _activeSosId = null;
    if (prevId != null) {
      debugPrint('[LocationUpdateService] Stopped tracking for SOS $prevId.');
    }
  }

  Future<void> _uploadLocation() async {
    if (!_isRunning || _activeSosId == null) return;

    final sosId = _activeSosId!;

    try {
      final position = await _getCurrentPosition();
      if (position == null) {
        debugPrint('[LocationUpdateService] Could not get GPS fix for SOS $sosId — skipping upload.');
        return;
      }

      final token = await AuthService().getToken();
      if (token == null || token.isEmpty) {
        debugPrint('[LocationUpdateService] No auth token — cannot upload location.');
        return;
      }

      final url = Uri.parse('${ApiConfig.baseUrl}/sos/$sosId/location');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        debugPrint(
          '[LocationUpdateService] Uploaded location: '
          '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)} '
          '(±${position.accuracy.toStringAsFixed(0)}m) for SOS $sosId.',
        );
      } else if (response.statusCode == 400) {
        // Incident is no longer ACTIVE — stop tracking
        debugPrint('[LocationUpdateService] Backend rejected upload (incident inactive) — stopping tracker.');
        stop();
      } else {
        debugPrint('[LocationUpdateService] Upload failed (HTTP ${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      debugPrint('[LocationUpdateService] Error uploading location: $e');
    }
  }

  Future<Position?> _getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return null;
      }

      // Try last-known first (fast, no GPS warm-up needed)
      Position? lastKnown;
      try {
        lastKnown = await Geolocator.getLastKnownPosition();
      } catch (_) {}

      // Try fresh position with 8 second timeout
      try {
        final fresh = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
        return fresh;
      } catch (_) {
        return lastKnown;
      }
    } catch (e) {
      debugPrint('[LocationUpdateService] _getCurrentPosition error: $e');
      return null;
    }
  }
}
