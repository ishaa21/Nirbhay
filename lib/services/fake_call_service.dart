import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../screens/fake_call_screen.dart';

class FakeCallPermissionStatus {
  final bool hasNotificationPermission;
  final bool hasExactAlarmPermission;
  final bool hasFullScreenIntentPermission;

  FakeCallPermissionStatus({
    required this.hasNotificationPermission,
    required this.hasExactAlarmPermission,
    required this.hasFullScreenIntentPermission,
  });

  bool get allGranted =>
      hasNotificationPermission &&
      hasExactAlarmPermission &&
      hasFullScreenIntentPermission;
}

class FakeCallTriggerInfo {
  final bool hasPendingTrigger;
  final String callerName;
  final String callerSubtitle;
  final bool isAccepted;

  FakeCallTriggerInfo({
    required this.hasPendingTrigger,
    required this.callerName,
    required this.callerSubtitle,
    required this.isAccepted,
  });
}

class FakeCallService {
  static final FakeCallService _instance = FakeCallService._internal();
  factory FakeCallService() => _instance;

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static const MethodChannel _channel = MethodChannel('com.ishaa21.nirbhay/fake_call');

  /// Active listeners for trigger events while app is foregrounded / backgrounded
  void Function(String callerName, String callerSubtitle, bool isAccepted)? onCallTriggered;
  void Function()? onCallCancelled;

  FakeCallService._internal() {
    _channel.setMethodCallHandler(_handleNativeMethodCall);
  }

  bool get isAndroid => !kIsWeb && Platform.isAndroid;

  Future<dynamic> _handleNativeMethodCall(MethodCall call) async {
    debugPrint('[FakeCallService] Received native call: ${call.method}');
    switch (call.method) {
      case 'onFakeCallTriggered':
        final args = Map<String, dynamic>.from(call.arguments ?? {});
        final callerName = args['callerName']?.toString() ?? 'Mom';
        final callerSubtitle = args['callerSubtitle']?.toString() ?? 'Mobile';
        final isAccepted = args['isAccepted'] == true;

        if (onCallTriggered != null) {
          onCallTriggered!(callerName, callerSubtitle, isAccepted);
        } else {
          // Navigate to FakeCallScreen via global navigator key if not already listening
          navigateToCallScreen(
            callerName: callerName,
            callerSubtitle: callerSubtitle,
            autoAccept: isAccepted,
          );
        }
        break;

      case 'onFakeCallCancelled':
        if (onCallCancelled != null) {
          onCallCancelled!();
        }
        break;
    }
  }

  /// Directs global navigation to the FakeCallScreen
  void navigateToCallScreen({
    required String callerName,
    required String callerSubtitle,
    required bool autoAccept,
  }) {
    final nav = navigatorKey.currentState;
    if (nav != null) {
      nav.push(
        MaterialPageRoute(
          builder: (_) => FakeCallScreen(
            initialCallerName: callerName,
            initialCallerSubtitle: callerSubtitle,
            autoAccept: autoAccept,
            isFromTrigger: true,
          ),
        ),
      );
    }
  }

  /// Schedules native Android Alarm for background and lock-screen invocation.
  Future<bool> scheduleFakeCall({
    required int delaySeconds,
    required String callerName,
    required String callerSubtitle,
    int avatarIndex = 0,
  }) async {
    if (!isAndroid) return true;
    try {
      final res = await _channel.invokeMethod<bool>('scheduleFakeCall', {
        'delaySeconds': delaySeconds,
        'callerName': callerName,
        'callerSubtitle': callerSubtitle,
        'avatarIndex': avatarIndex,
      });
      return res == true;
    } catch (e) {
      debugPrint('[FakeCallService] scheduleFakeCall error: $e');
      return false;
    }
  }

  /// Cancels scheduled alarm & any active notification.
  Future<bool> cancelScheduledFakeCall() async {
    if (!isAndroid) return true;
    try {
      final res = await _channel.invokeMethod<bool>('cancelScheduledFakeCall');
      return res == true;
    } catch (e) {
      debugPrint('[FakeCallService] cancelScheduledFakeCall error: $e');
      return false;
    }
  }

  /// Stops native ringtone, vibration, and removes call notification.
  Future<bool> stopRingtone() async {
    if (!isAndroid) return true;
    try {
      final res = await _channel.invokeMethod<bool>('stopRingtone');
      return res == true;
    } catch (e) {
      debugPrint('[FakeCallService] stopRingtone error: $e');
      return false;
    }
  }

  /// Checks if app was opened/resumed via an incoming call notification or action.
  Future<FakeCallTriggerInfo> getPendingTrigger() async {
    if (!isAndroid) {
      return FakeCallTriggerInfo(
        hasPendingTrigger: false,
        callerName: 'Mom',
        callerSubtitle: 'Mobile',
        isAccepted: false,
      );
    }
    try {
      final res = await _channel.invokeMethod<Map>('getPendingTrigger');
      final map = Map<String, dynamic>.from(res ?? {});
      return FakeCallTriggerInfo(
        hasPendingTrigger: map['hasPendingTrigger'] == true,
        callerName: map['callerName']?.toString() ?? 'Mom',
        callerSubtitle: map['callerSubtitle']?.toString() ?? 'Mobile',
        isAccepted: map['isAccepted'] == true,
      );
    } catch (e) {
      debugPrint('[FakeCallService] getPendingTrigger error: $e');
      return FakeCallTriggerInfo(
        hasPendingTrigger: false,
        callerName: 'Mom',
        callerSubtitle: 'Mobile',
        isAccepted: false,
      );
    }
  }

  /// Checks OS permission status for notifications, exact alarms, and full-screen intents.
  Future<FakeCallPermissionStatus> checkPermissions() async {
    if (!isAndroid) {
      return FakeCallPermissionStatus(
        hasNotificationPermission: true,
        hasExactAlarmPermission: true,
        hasFullScreenIntentPermission: true,
      );
    }
    try {
      final res = await _channel.invokeMethod<Map>('checkPermissions');
      final map = Map<String, dynamic>.from(res ?? {});
      return FakeCallPermissionStatus(
        hasNotificationPermission: map['hasNotificationPermission'] == true,
        hasExactAlarmPermission: map['hasExactAlarmPermission'] == true,
        hasFullScreenIntentPermission: map['hasFullScreenIntentPermission'] == true,
      );
    } catch (e) {
      debugPrint('[FakeCallService] checkPermissions error: $e');
      return FakeCallPermissionStatus(
        hasNotificationPermission: true,
        hasExactAlarmPermission: true,
        hasFullScreenIntentPermission: true,
      );
    }
  }

  Future<void> requestNotificationPermission() async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod('requestNotificationPermission');
    } catch (e) {
      debugPrint('[FakeCallService] requestNotificationPermission error: $e');
    }
  }

  Future<void> requestExactAlarmPermission() async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod('requestExactAlarmPermission');
    } catch (e) {
      debugPrint('[FakeCallService] requestExactAlarmPermission error: $e');
    }
  }

  Future<void> requestFullScreenIntentPermission() async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod('requestFullScreenIntentPermission');
    } catch (e) {
      debugPrint('[FakeCallService] requestFullScreenIntentPermission error: $e');
    }
  }
}
