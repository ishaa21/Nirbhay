import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Native Android SMS via platform channel (SmsManager + sent/delivery callbacks).
class DeviceSmsService {
  static final DeviceSmsService _instance = DeviceSmsService._internal();
  factory DeviceSmsService() => _instance;
  DeviceSmsService._internal();

  static const MethodChannel _methodChannel =
      MethodChannel('com.ishaa21.nirbhay/sms');
  static const EventChannel _eventChannel =
      EventChannel('com.ishaa21.nirbhay/sms_events');

  Stream<Map<String, dynamic>>? _eventStream;
  final Map<String, _SmsOutcome> _outcomes = {};

  /// Set true in unit tests only (mock method channel; never sends real SMS).
  @visibleForTesting
  static bool simulateAndroidForTests = false;

  bool get isAndroid =>
      !kIsWeb && (Platform.isAndroid || simulateAndroidForTests);

  Stream<Map<String, dynamic>> get smsEvents {
    _eventStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => Map<String, dynamic>.from(event as Map));
    return _eventStream!;
  }

  Future<Map<String, dynamic>> checkCapabilities() async {
    if (!isAndroid) {
      return {
        'platform': defaultTargetPlatform.name,
        'smsSupported': false,
        'hasSendSmsPermission': false,
        'simReady': false,
      };
    }
    final raw = await _methodChannel.invokeMethod<Map>('checkCapabilities');
    return Map<String, dynamic>.from(raw ?? {});
  }

  Future<bool> requestSendPermission() async {
    if (!isAndroid) return false;
    final raw = await _methodChannel.invokeMethod<Map>('requestPermission');
    final map = Map<String, dynamic>.from(raw ?? {});
    return map['granted'] == true;
  }

  /// Send batch; returns immediate SmsManager submission results (usually PENDING).
  Future<List<DeviceSmsSendResult>> sendMessages(
    List<DeviceSmsMessage> messages,
  ) async {
    if (!isAndroid || messages.isEmpty) {
      return messages
          .map(
            (m) => DeviceSmsSendResult(
              clientRequestId: m.clientRequestId,
              status: 'FAILED',
              errorMessage: 'Direct SMS is only supported on Android.',
            ),
          )
          .toList();
    }

    final payload = messages
        .map(
          (m) => {
            'clientRequestId': m.clientRequestId,
            'phone': m.phone,
            'body': m.body,
          },
        )
        .toList();

    final raw = await _methodChannel.invokeMethod<Map>('sendMessages', {
      'messages': payload,
    });
    final map = Map<String, dynamic>.from(raw ?? {});
    if (map['success'] != true && map['errorCode'] != null) {
      final err = map['errorMessage']?.toString() ?? map['errorCode'].toString();
      return messages
          .map(
            (m) => DeviceSmsSendResult(
              clientRequestId: m.clientRequestId,
              status: 'FAILED',
              errorMessage: err,
            ),
          )
          .toList();
    }

    final results = (map['results'] as List?) ?? [];
    return results.map((r) {
      final item = Map<String, dynamic>.from(r as Map);
      return DeviceSmsSendResult(
        clientRequestId: item['clientRequestId']?.toString() ?? '',
        status: item['status']?.toString() ?? 'FAILED',
        errorMessage: item['errorMessage']?.toString(),
      );
    }).toList();
  }

  /// Wait for sent/delivery callbacks for known clientRequestIds (with timeout).
  Future<Map<String, _SmsOutcome>> waitForOutcomes(
    Set<String> clientRequestIds, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final deadline = DateTime.now().add(timeout);
    late StreamSubscription<Map<String, dynamic>> sub;

    sub = smsEvents.listen((event) {
      final id = event['clientRequestId']?.toString();
      if (id == null || !clientRequestIds.contains(id)) return;
      final type = event['type']?.toString();
      final status = event['status']?.toString() ?? 'FAILED';
      final existing = _outcomes[id];
      if (type == 'sent') {
        _outcomes[id] = _SmsOutcome(
          sentStatus: status,
          sentError: event['errorMessage']?.toString(),
          deliveredStatus: existing?.deliveredStatus,
        );
      } else if (type == 'delivered') {
        _outcomes[id] = _SmsOutcome(
          sentStatus: existing?.sentStatus ?? 'SENT',
          sentError: existing?.sentError,
          deliveredStatus: status,
          deliveredError: event['errorMessage']?.toString(),
        );
      }
    });

    while (DateTime.now().isBefore(deadline)) {
      final allSent = clientRequestIds.every((id) {
        final o = _outcomes[id];
        return o != null && o.sentStatus != null && o.sentStatus != 'PENDING';
      });
      if (allSent) break;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }

    await sub.cancel();
    return Map.fromEntries(
      clientRequestIds.map((id) => MapEntry(id, _outcomes[id] ?? _SmsOutcome())),
    );
  }

  void clearOutcomes([Iterable<String>? ids]) {
    if (ids != null) {
      for (final id in ids) {
        _outcomes.remove(id);
      }
    } else {
      _outcomes.clear();
    }
  }
}

class DeviceSmsMessage {
  final String clientRequestId;
  final String phone;
  final String body;

  DeviceSmsMessage({
    required this.clientRequestId,
    required this.phone,
    required this.body,
  });
}

class DeviceSmsSendResult {
  final String clientRequestId;
  final String status;
  final String? errorMessage;

  DeviceSmsSendResult({
    required this.clientRequestId,
    required this.status,
    this.errorMessage,
  });
}

class _SmsOutcome {
  final String? sentStatus;
  final String? sentError;
  final String? deliveredStatus;
  final String? deliveredError;

  _SmsOutcome({
    this.sentStatus,
    this.sentError,
    this.deliveredStatus,
    this.deliveredError,
  });
}
