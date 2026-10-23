import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_service.dart';
import 'sos_service.dart';

enum TrackingState {
  idle,
  starting,
  tracking,
  stale,
  permissionDenied,
  gpsDisabled,
  networkError,
  authExpired,
  stopped,
}

class TrackingStatus {
  final TrackingState state;
  final Position? position;
  final DateTime? lastSuccessfulUploadTime;
  final String? message;

  const TrackingStatus({
    required this.state,
    this.position,
    this.lastSuccessfulUploadTime,
    this.message,
  });

  bool get isStale {
    if (lastSuccessfulUploadTime == null) return false;
    return DateTime.now().difference(lastSuccessfulUploadTime!).inSeconds > 60;
  }
}

/// Continuous GPS uploads for active SOS incidents and/or live journey sessions.
class LocationUpdateService {
  static final LocationUpdateService _instance = LocationUpdateService._internal();
  factory LocationUpdateService() => _instance;
  LocationUpdateService._internal();

  Timer? _heartbeatTimer;
  StreamSubscription<Position>? _positionStreamSub;
  String? _activeSosId;
  String? _activeJourneyId;
  bool _isRunning = false;

  Position? _lastPosition;
  DateTime? _lastSuccessfulUploadTime;
  DateTime? _lastUploadAttemptTime;
  TrackingState _state = TrackingState.idle;
  String? _statusMessage;

  final ValueNotifier<TrackingStatus> statusNotifier = ValueNotifier<TrackingStatus>(
    const TrackingStatus(state: TrackingState.idle),
  );

  /// Offline coordinate queue for network resilience (max 20 breadcrumbs)
  final List<Map<String, dynamic>> _offlineQueue = [];

  /// Minimum interval between consecutive HTTP uploads to preserve battery.
  static const Duration _minUploadInterval = Duration(seconds: 10);

  /// Heartbeat interval to check GPS fix and upload even if movement stream is quiet.
  static const Duration _heartbeatInterval = Duration(seconds: 15);

  bool get isRunning => _isRunning;
  String? get activeSosId => _activeSosId;
  String? get activeJourneyId => _activeJourneyId;
  Position? get lastPosition => _lastPosition;
  DateTime? get lastSuccessfulUploadTime => _lastSuccessfulUploadTime;
  TrackingState get state => _state;
  int get queuedOfflineUpdatesCount => _offlineQueue.length;
  bool get isStale =>
      _lastSuccessfulUploadTime != null &&
      DateTime.now().difference(_lastSuccessfulUploadTime!).inSeconds > 60;

  void _notify(TrackingState newState, {String? msg, Position? pos}) {
    _state = newState;
    if (msg != null) _statusMessage = msg;
    if (pos != null) _lastPosition = pos;

    statusNotifier.value = TrackingStatus(
      state: _state,
      position: _lastPosition,
      lastSuccessfulUploadTime: _lastSuccessfulUploadTime,
      message: _statusMessage,
    );
  }

  bool get _hasUploadTarget => _activeSosId != null || _activeJourneyId != null;

  /// Start or update GPS uploads. Pass [sosId] and/or [journeyId].
  Future<void> start({String? sosId, String? journeyId}) async {
    if (sosId == null && journeyId == null) {
      debugPrint('[LocationUpdateService] start() called with no SOS or journey id.');
      return;
    }

    final sameSession = _isRunning &&
        _activeSosId == sosId &&
        _activeJourneyId == journeyId;
    if (sameSession) {
      return;
    }

    final keepStream = _isRunning && _positionStreamSub != null;
    if (!keepStream) {
      _heartbeatTimer?.cancel();
      _positionStreamSub?.cancel();
      _isRunning = false;
    }

    _activeSosId = sosId;
    _activeJourneyId = journeyId;
    _isRunning = true;

    _notify(
      TrackingState.starting,
      msg: 'Initializing GPS for ${sosId != null ? "SOS" : ""}${sosId != null && journeyId != null ? " + " : ""}${journeyId != null ? "journey" : ""}...',
    );

    if (!keepStream) {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _notify(TrackingState.gpsDisabled, msg: 'Device location (GPS) is disabled.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        _notify(TrackingState.permissionDenied, msg: 'Location permission was denied.');
        return;
      }

      await _fetchAndUploadInitialFix();
      _startLocationStream();

      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
        if (!_isRunning || !_hasUploadTarget) {
          _heartbeatTimer?.cancel();
          return;
        }
        _performPeriodicFixAndUpload();
      });
    } else {
      await _fetchAndUploadInitialFix();
    }
  }

  /// Backward-compatible: start SOS-only tracking.
  Future<void> startSos(String sosId) => start(sosId: sosId);

  void setActiveJourney(String? journeyId) {
    _activeJourneyId = journeyId;
    if (journeyId != null && !_isRunning) {
      start(journeyId: journeyId, sosId: _activeSosId);
    } else if (journeyId == null && _activeSosId == null && _isRunning) {
      stop();
    }
  }

  void _startLocationStream() {
    _positionStreamSub?.cancel();

    LocationSettings locationSettings;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        forceLocationManager: true,
        intervalDuration: const Duration(seconds: 15),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Nirbhay Live Tracking Active',
          notificationText: 'Sharing your live location with guardians.',
          enableWakeLock: true,
        ),
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );
    }

    try {
      _positionStreamSub = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          _lastPosition = position;
          SosService.cacheLocationFix(
            position.latitude,
            position.longitude,
            position.timestamp,
          );
          _uploadPositionIfEligible(position);
        },
        onError: (err) {
          debugPrint('[LocationUpdateService] Position stream error: $err');
          _notify(TrackingState.networkError, msg: 'GPS stream error: $err');
        },
      );
    } catch (e) {
      debugPrint('[LocationUpdateService] Failed to initialize position stream: $e');
    }
  }

  Future<void> _fetchAndUploadInitialFix() async {
    Position? pos;
    try {
      pos = await Geolocator.getLastKnownPosition();
    } catch (_) {}

    if (pos == null) {
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 6),
          ),
        );
      } catch (_) {}
    }

    if (pos != null) {
      _lastPosition = pos;
      SosService.cacheLocationFix(
        pos.latitude,
        pos.longitude,
        pos.timestamp,
      );
      await _uploadPositionToBackend(pos);
    }
  }

  Future<void> _performPeriodicFixAndUpload() async {
    final now = DateTime.now();
    if (_lastUploadAttemptTime != null &&
        now.difference(_lastUploadAttemptTime!) < _minUploadInterval) {
      return;
    }

    Position? pos = _lastPosition;
    try {
      pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 6),
        ),
      );
    } catch (_) {}

    if (pos != null) {
      _lastPosition = pos;
      SosService.cacheLocationFix(
        pos.latitude,
        pos.longitude,
        pos.timestamp,
      );
      await _uploadPositionToBackend(pos);
    }
  }

  void _uploadPositionIfEligible(Position position) {
    final now = DateTime.now();
    if (_lastUploadAttemptTime != null &&
        now.difference(_lastUploadAttemptTime!) < _minUploadInterval) {
      return;
    }
    _uploadPositionToBackend(position);
  }

  Future<void> _uploadPositionToBackend(Position position) async {
    if (!_isRunning || !_hasUploadTarget) return;

    _lastUploadAttemptTime = DateTime.now();

    final currentFix = {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy': position.accuracy,
      'speed': position.speed >= 0 ? position.speed : null,
      'heading': position.heading >= 0 ? position.heading : null,
      'recorded_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      // If the active SOS incident was created offline, attempt background sync first
      if (_activeSosId != null && _activeSosId!.startsWith('offline_')) {
        await SosService().syncPendingOfflineSos();
        if (_activeSosId != null && _activeSosId!.startsWith('offline_')) {
          // Still offline — buffer fix and return
          if (_offlineQueue.length >= 20) {
            _offlineQueue.removeAt(0);
          }
          _offlineQueue.add(currentFix);
          return;
        }
      }

      final token = await AuthService().getToken();
      if (token == null || token.isEmpty) {
        _notify(TrackingState.authExpired, msg: 'No auth token available.');
        return;
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      // Bundle pending offline fixes together with current fix for atomic replay
      final List<Map<String, dynamic>> payloadUpdates = [
        ..._offlineQueue,
        currentFix,
      ];

      final body = jsonEncode({
        'updates': payloadUpdates,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'speed': position.speed >= 0 ? position.speed : null,
        'heading': position.heading >= 0 ? position.heading : null,
      });

      bool anySuccess = false;
      bool sosInactive = false;

      if (_activeSosId != null) {
        final sosId = _activeSosId!;
        final url = Uri.parse('${ApiConfig.baseUrl}/sos/$sosId/location');
        final response = await http
            .post(url, headers: headers, body: body)
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          anySuccess = true;
          _offlineQueue.clear();
        } else if (response.statusCode == 400) {
          sosInactive = true;
          _activeSosId = null;
        } else if (response.statusCode == 401) {
          _notify(TrackingState.authExpired, msg: 'Session expired (HTTP 401).');
          return;
        }
      }

      if (_activeJourneyId != null) {
        final journeyId = _activeJourneyId!;
        final url = Uri.parse('${ApiConfig.baseUrl}/journey/$journeyId/location');
        final response = await http
            .post(url, headers: headers, body: body)
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          anySuccess = true;
          _offlineQueue.clear();
        } else if (response.statusCode == 400) {
          _activeJourneyId = null;
        } else if (response.statusCode == 401) {
          _notify(TrackingState.authExpired, msg: 'Session expired (HTTP 401).');
          return;
        }
      }

      if (anySuccess) {
        _lastSuccessfulUploadTime = DateTime.now();
        _notify(
          TrackingState.tracking,
          pos: position,
          msg: 'Location fix uploaded successfully.',
        );
      } else if (sosInactive && _activeJourneyId == null) {
        _notify(TrackingState.stopped, msg: 'Tracking session ended.');
        stop();
      } else if (!_hasUploadTarget) {
        stop();
      }
    } catch (e) {
      // Buffer fix into offline queue (capped at 20) for replay upon reconnection
      if (_offlineQueue.length >= 20) {
        _offlineQueue.removeAt(0);
      }
      _offlineQueue.add(currentFix);

      _notify(TrackingState.networkError, msg: 'Network error uploading location: $e');
      debugPrint('[LocationUpdateService] Error uploading location (buffered ${_offlineQueue.length} offline): $e');
    }
  }

  void stopJourneyTracking() {
    _activeJourneyId = null;
    if (_activeSosId == null) {
      stop();
    }
  }

  void stop() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    _positionStreamSub?.cancel();
    _positionStreamSub = null;

    _isRunning = false;
    _activeSosId = null;
    _activeJourneyId = null;
    _offlineQueue.clear();

    _notify(TrackingState.stopped, msg: 'Tracking stopped.');
  }
}
