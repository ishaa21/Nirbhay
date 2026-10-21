import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'sos_service.dart';

enum ShakeSosEventType {
  countdownStarted,
  countdownTick,
  countdownCancelled,
  countdownExpired,
}

class ShakeSosEvent {
  final ShakeSosEventType type;
  final int remainingSeconds;
  final int? endTimeMs;

  ShakeSosEvent({
    required this.type,
    this.remainingSeconds = 0,
    this.endTimeMs,
  });

  factory ShakeSosEvent.fromMap(Map<dynamic, dynamic> map) {
    final typeStr = map['type']?.toString();
    final remaining = map['remainingSeconds'] is int ? map['remainingSeconds'] as int : 0;
    final endTime = map['endTimeMs'] is int ? map['endTimeMs'] as int : null;

    ShakeSosEventType eventType;
    switch (typeStr) {
      case 'countdown_started':
        eventType = ShakeSosEventType.countdownStarted;
        break;
      case 'countdown_tick':
        eventType = ShakeSosEventType.countdownTick;
        break;
      case 'countdown_cancelled':
        eventType = ShakeSosEventType.countdownCancelled;
        break;
      case 'countdown_expired':
        eventType = ShakeSosEventType.countdownExpired;
        break;
      default:
        eventType = ShakeSosEventType.countdownTick;
    }

    return ShakeSosEvent(
      type: eventType,
      remainingSeconds: remaining,
      endTimeMs: endTime,
    );
  }
}

/// Service managing background Shake-to-SOS detection, 15-second countdown,
/// authoritative cancellation, and automatic single SOS dispatch.
class ShakeSosService {
  static final ShakeSosService _instance = ShakeSosService._internal();
  factory ShakeSosService() => _instance;
  ShakeSosService._internal() {
    _initEventListener();
  }

  static const MethodChannel _methodChannel = MethodChannel('com.ishaa21.nirbhay/shake_sos');
  static const EventChannel _eventChannel = EventChannel('com.ishaa21.nirbhay/shake_events');

  /// Set true during automated tests to simulate native behavior without hardware.
  @visibleForTesting
  static bool simulateForTests = false;

  bool get isAndroid => !kIsWeb && (Platform.isAndroid || simulateForTests);

  final StreamController<ShakeSosEvent> _eventController = StreamController<ShakeSosEvent>.broadcast();
  Stream<ShakeSosEvent> get shakeEvents => _eventController.stream;

  StreamSubscription? _nativeSubscription;
  bool _isSosTriggering = false;

  void _initEventListener() {
    if (kIsWeb) return;
    try {
      _nativeSubscription = _eventChannel.receiveBroadcastStream().listen((dynamic event) {
        if (event is Map) {
          final shakeEvent = ShakeSosEvent.fromMap(event);
          _eventController.add(shakeEvent);

          if (shakeEvent.type == ShakeSosEventType.countdownExpired) {
            handleCountdownExpired();
          }
        }
      }, onError: (err) {
        debugPrint('[ShakeSosService] EventChannel error: $err');
      });
    } catch (e) {
      debugPrint('[ShakeSosService] Could not attach EventChannel: $e');
    }
  }

  /// Whether Shake-to-SOS background service is currently enabled.
  Future<bool> isServiceEnabled() async {
    if (!isAndroid) return false;
    try {
      final res = await _methodChannel.invokeMethod<bool>('isServiceEnabled');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Start background monitoring service.
  Future<bool> startShakeService() async {
    if (!isAndroid) return false;
    try {
      final res = await _methodChannel.invokeMethod<bool>('startService');
      return res ?? false;
    } catch (e) {
      debugPrint('[ShakeSosService] Failed to start service: $e');
      return false;
    }
  }

  /// Stop background monitoring service.
  Future<bool> stopShakeService() async {
    if (!isAndroid) return false;
    try {
      final res = await _methodChannel.invokeMethod<bool>('stopService');
      return res ?? false;
    } catch (e) {
      debugPrint('[ShakeSosService] Failed to stop service: $e');
      return false;
    }
  }

  /// Authoritatively cancel an active countdown.
  Future<bool> cancelCountdown() async {
    _isSosTriggering = false;
    if (!isAndroid) {
      _eventController.add(ShakeSosEvent(type: ShakeSosEventType.countdownCancelled));
      return true;
    }
    try {
      final res = await _methodChannel.invokeMethod<bool>('cancelCountdown');
      _eventController.add(ShakeSosEvent(type: ShakeSosEventType.countdownCancelled));
      return res ?? false;
    } catch (e) {
      debugPrint('[ShakeSosService] Failed to cancel countdown: $e');
      return false;
    }
  }

  /// Query current active countdown state from persistent storage.
  Future<Map<String, dynamic>> getCountdownState() async {
    if (!isAndroid) {
      return {'isActive': false, 'remainingSeconds': 0};
    }
    try {
      final res = await _methodChannel.invokeMethod<Map>('getCountdownState');
      if (res != null) {
        return Map<String, dynamic>.from(res);
      }
      return {'isActive': false, 'remainingSeconds': 0};
    } catch (_) {
      return {'isActive': false, 'remainingSeconds': 0};
    }
  }

  /// Set shake sensitivity level ('LOW', 'DEFAULT', 'HIGH').
  Future<bool> setSensitivity(String sensitivity) async {
    if (!isAndroid) return false;
    try {
      final res = await _methodChannel.invokeMethod<bool>('setSensitivity', {'sensitivity': sensitivity});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Returns true if the app is allowed to use full-screen intents.
  ///
  /// On Android 14 (API 34) and above, this requires the user to explicitly
  /// grant USE_FULL_SCREEN_INTENT via Settings → Apps → Special app access.
  /// On Android 13 and below, declaring the permission in the manifest is sufficient
  /// and this always returns true.
  Future<bool> canUseFullScreenIntent() async {
    if (!isAndroid) return false;
    try {
      final res = await _methodChannel.invokeMethod<bool>('canUseFullScreenIntent');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Returns true if the app has the SYSTEM_ALERT_WINDOW (draw-over-other-apps) permission.
  ///
  /// On Android 6.0+ this must be granted by the user via Settings.
  /// On older versions it is always true.
  Future<bool> canDrawOverlays() async {
    if (!isAndroid) return false;
    try {
      final res = await _methodChannel.invokeMethod<bool>('canDrawOverlays');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Returns whether notification permission is granted (Android 13+).
  Future<bool> hasNotificationPermission() async {
    if (!isAndroid) return true;
    try {
      final res = await _methodChannel.invokeMethod<bool>('hasNotificationPermission');
      return res ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Requests notification permission on Android 13+ (API 33+).
  Future<void> requestNotificationPermission() async {
    if (!isAndroid) return;
    try {
      await _methodChannel.invokeMethod('requestNotificationPermission');
    } catch (e) {
      debugPrint('[ShakeSosService] Failed to request notification permission: $e');
    }
  }

  /// Opens the system notification settings screen for this app.
  ///
  /// Use this to help the user grant USE_FULL_SCREEN_INTENT on Android 14+
  /// or enable notification channels that may have been blocked.
  Future<void> openNotificationSettings() async {
    if (!isAndroid) return;
    try {
      await _methodChannel.invokeMethod('openNotificationSettings');
    } catch (e) {
      debugPrint('[ShakeSosService] Failed to open notification settings: $e');
    }
  }

  /// Opens the system overlay permission settings screen for this app (SYSTEM_ALERT_WINDOW).
  Future<void> requestOverlayPermission() async {
    if (!isAndroid) return;
    try {
      await _methodChannel.invokeMethod('requestOverlayPermission');
    } catch (e) {
      debugPrint('[ShakeSosService] Failed to open overlay settings: $e');
    }
  }

  /// Handler invoked on SOS trigger. Defaults to SosService().createSos().
  /// Can be overridden for unit testing.
  @visibleForTesting
  Future<Map<String, dynamic>> Function()? onSosTrigger;

  /// Invoked when countdown expires without cancellation.
  /// Authoritatively triggers the existing SOS workflow exactly once.
  Future<void> handleCountdownExpired() async {
    if (_isSosTriggering) {
      debugPrint('[ShakeSosService] SOS activation already in progress. Ignoring duplicate.');
      return;
    }
    _isSosTriggering = true;
    try {
      debugPrint('[ShakeSosService] 15s Countdown expired! Automatically activating SOS...');
      if (onSosTrigger != null) {
        await onSosTrigger!();
      } else {
        final result = await SosService().createSos();
        debugPrint('[ShakeSosService] Shake SOS triggered result: ${result['success']}');
      }
    } catch (e) {
      debugPrint('[ShakeSosService] Error triggering SOS after countdown: $e');
    } finally {
      _isSosTriggering = false;
    }
  }

  @visibleForTesting
  void simulateEvent(ShakeSosEvent event) {
    _eventController.add(event);
    if (event.type == ShakeSosEventType.countdownExpired) {
      handleCountdownExpired();
    }
  }

  void dispose() {
    _nativeSubscription?.cancel();
  }
}
