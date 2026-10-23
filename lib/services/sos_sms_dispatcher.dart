import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/emergency_contact_model.dart';
import 'api_config.dart';
import 'auth_service.dart';
import '../utils/phone_normalizer.dart';
import 'device_sms_service.dart';

/// Sends SOS SMS from the Android device and reports results to the backend.
class SosSmsDispatcher {
  static final SosSmsDispatcher _instance = SosSmsDispatcher._internal();
  factory SosSmsDispatcher() => _instance;
  SosSmsDispatcher._internal();

  final DeviceSmsService _deviceSms = DeviceSmsService();

  /// Tracks currently in-flight dispatches by a composite key of
  /// `sosId:sortedNotificationIds`. Allows the initial SOS alert dispatch
  /// and the resolve ("user is safe") dispatch for the same incident to run
  /// concurrently, because they carry different notification row IDs.
  final Set<String> _inFlightDispatchKeys = {};
  final Set<String> _completedNotificationIds = {};

  /// Tracks incidents/sessions that have already dispatched an initial SOS alert SMS.
  /// Used to prevent duplicate SMS dispatches when backend incident synchronization finishes.
  final Set<String> _dispatchedSosAlertSessions = {};

  /// Build a stable key from the notification IDs in this batch.
  @visibleForTesting
  String dispatchKey(String sosId, List<dynamic> recipients) {
    final ids = recipients
        .map((r) => (r as Map)['notificationId']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList()
      ..sort();
    return '$sosId:${ids.join(",")}';
  }

  /// Link an offline local incident ID with the backend server ID
  /// so that duplicate SMS is not sent when backend registration syncs.
  void linkIncidents(String localId, String backendId) {
    if (_dispatchedSosAlertSessions.contains(localId)) {
      _dispatchedSosAlertSessions.add(backendId);
    }
    if (_dispatchedSosAlertSessions.contains(backendId)) {
      _dispatchedSosAlertSessions.add(localId);
    }
  }

  @visibleForTesting
  void clearDispatchedSessions() {
    _dispatchedSosAlertSessions.clear();
  }

  /// Direct SIM SMS dispatch for emergency contacts without requiring prior backend call.
  /// Operates purely on-device via native SmsManager.
  Future<Map<String, dynamic>> dispatchDirectSms({
    required String sosId,
    required List<EmergencyContactModel> contacts,
    required String messageBody,
  }) async {
    if (contacts.isEmpty) {
      return {
        'success': false,
        'status': 'NO_CONTACTS',
        'message': 'No emergency contacts configured to receive SMS alerts.',
      };
    }

    if (!_deviceSms.isAndroid) {
      debugPrint('[SOS SMS] Direct SIM SMS requires Android.');
      return {
        'success': false,
        'status': 'NOT_ANDROID',
        'message': 'Direct SMS is only available on Android.',
      };
    }

    if (_dispatchedSosAlertSessions.contains(sosId)) {
      debugPrint('[SOS SMS] Alert SMS already dispatched for incident $sosId.');
      return {
        'success': true,
        'status': 'ALREADY_DISPATCHED',
        'message': 'Alert SMS already dispatched for this SOS incident.',
      };
    }

    final recipients = contacts.map((c) {
      final normPhone = normalizePhoneNumber(c.phone);
      return {
        'notificationId': 'direct_${c.id}_${DateTime.now().millisecondsSinceEpoch}',
        'contactId': c.id,
        'contactName': c.name,
        'contactPhone': c.phone,
        'dispatchPhone': normPhone,
        'simulateOnly': false,
      };
    }).toList();

    await dispatchDeviceSmsPayload(
      sosId: sosId,
      deviceSms: {
        'messageBody': messageBody,
        'recipients': recipients,
      },
    );

    return {
      'success': true,
      'status': 'DISPATCHED',
      'recipientsCount': recipients.length,
      'message': 'Emergency SMS dispatched directly via SIM.',
    };
  }

  Future<void> dispatchDeviceSmsPayload({
    required String sosId,
    required Map<String, dynamic>? deviceSms,
  }) async {
    if (deviceSms == null) return;

    final recipients = (deviceSms['recipients'] as List?) ?? [];
    if (recipients.isEmpty) return;

    final messageBody = deviceSms['messageBody']?.toString() ?? '';
    final isResolve = messageBody.contains('RESOLVED') || messageBody.contains('SAFE');

    // Deduplication check: if initial alert was already dispatched for this incident/session,
    // skip re-transmitting duplicate SMS over cellular SIM, but report results to backend.
    if (!isResolve && _dispatchedSosAlertSessions.contains(sosId)) {
      debugPrint('[SOS SMS] SOS alert SMS already dispatched for incident $sosId. Skipping duplicate cellular dispatch.');
      final reportList = recipients.map((r) {
        final nid = (r as Map)['notificationId']?.toString() ?? '';
        return {
          'notificationId': nid,
          'status': 'SENT',
          'providerMessageId': 'DEVICE_DIRECT_SENT',
        };
      }).where((m) => (m['notificationId'] as String).isNotEmpty).toList();
      if (reportList.isNotEmpty) {
        await _reportResults(sosId, reportList);
      }
      return;
    }

    final currentDispatchKey = dispatchKey(sosId, recipients);
    if (_inFlightDispatchKeys.contains(currentDispatchKey)) {
      debugPrint('[SOS SMS] Dispatch already in progress for key $currentDispatchKey.');
      return;
    }

    if (!_deviceSms.isAndroid) {
      debugPrint('[SOS SMS] Skipping — direct SMS requires Android.');
      await _reportAllFailed(
        sosId,
        recipients,
        'Direct SMS is only available on Android.',
      );
      return;
    }

    _inFlightDispatchKeys.add(currentDispatchKey);
    try {
      final caps = await _deviceSms.checkCapabilities();
      if (caps['hasSendSmsPermission'] != true) {
        final granted = await _deviceSms.requestSendPermission();
        if (!granted) {
          await _reportAllFailed(
            sosId,
            recipients,
            'SEND_SMS permission denied. Enable SMS permission in app settings to alert emergency contacts.',
          );
          return;
        }
      }

      if (caps['simReady'] == false) {
        final recheck = await _deviceSms.checkCapabilities();
        if (recheck['simReady'] != true) {
          await _reportAllFailed(
            sosId,
            recipients,
            'No ready SIM or SMS service unavailable on this device.',
          );
          return;
        }
      }

      final toSend = <DeviceSmsMessage>[];
      final clientIdToNotification = <String, String>{};

      for (final raw in recipients) {
        final r = Map<String, dynamic>.from(raw as Map);
        final notificationId = r['notificationId']?.toString() ?? '';
        if (notificationId.isEmpty) continue;
        if (_completedNotificationIds.contains(notificationId)) continue;

        if (r['simulateOnly'] == true) {
          await _reportResults(sosId, [
            {
              'notificationId': notificationId,
              'status': 'PENDING',
              'providerMessageId': 'DEVICE_TEST_SIMULATED',
            },
          ]);
          _completedNotificationIds.add(notificationId);
          continue;
        }

        final phone = r['dispatchPhone']?.toString() ?? '';
        if (phone.isEmpty) {
          await _reportResults(sosId, [
            {
              'notificationId': notificationId,
              'status': 'FAILED',
              'errorMessage': 'Invalid dispatch phone number.',
            },
          ]);
          continue;
        }

        final clientRequestId = 'nirbhay_${sosId}_$notificationId';
        clientIdToNotification[clientRequestId] = notificationId;
        toSend.add(
          DeviceSmsMessage(
            clientRequestId: clientRequestId,
            phone: phone,
            body: messageBody,
          ),
        );
      }

      if (toSend.isEmpty) return;

      if (!isResolve) {
        _dispatchedSosAlertSessions.add(sosId);
      }

      _deviceSms.clearOutcomes(toSend.map((m) => m.clientRequestId));
      final immediate = await _deviceSms.sendMessages(toSend);
      final pendingIds = <String>{};

      final batchResults = <Map<String, dynamic>>[];
      for (final res in immediate) {
        final notificationId = clientIdToNotification[res.clientRequestId];
        if (notificationId == null) continue;

        if (res.status == 'PENDING') {
          pendingIds.add(res.clientRequestId);
          batchResults.add({
            'notificationId': notificationId,
            'status': 'PENDING',
            'providerMessageId': res.clientRequestId,
          });
        } else {
          batchResults.add({
            'notificationId': notificationId,
            'status': 'FAILED',
            'errorMessage': res.errorMessage ?? 'SMS send failed.',
          });
          _completedNotificationIds.add(notificationId);
        }
      }
      await _reportResults(sosId, batchResults);

      if (pendingIds.isEmpty) return;

      final outcomes = await _deviceSms.waitForOutcomes(pendingIds);
      final followUp = <Map<String, dynamic>>[];
      for (final clientId in pendingIds) {
        final notificationId = clientIdToNotification[clientId];
        if (notificationId == null) continue;
        final outcome = outcomes[clientId];
        final sent = outcome?.sentStatus ?? 'PENDING';
        if (sent == 'FAILED') {
          followUp.add({
            'notificationId': notificationId,
            'status': 'FAILED',
            'errorMessage': outcome?.sentError ?? 'SMS send failed.',
          });
        } else if (sent == 'SENT') {
          followUp.add({
            'notificationId': notificationId,
            'status': 'SENT',
            'providerMessageId': clientId,
          });
          if (outcome?.deliveredStatus == 'DELIVERED') {
            followUp.add({
              'notificationId': notificationId,
              'status': 'DELIVERED',
              'providerMessageId': clientId,
            });
          }
        }
        _completedNotificationIds.add(notificationId);
      }
      if (followUp.isNotEmpty) {
        await _reportResults(sosId, followUp);
      }
    } finally {
      _inFlightDispatchKeys.remove(currentDispatchKey);
    }
  }

  /// Dispatch pending DEVICE SMS for an active incident (e.g. safety timer expiry on server).
  Future<void> dispatchPendingForActiveIncident({
    required String sosId,
    required List<dynamic> notifications,
    required String messageBody,
  }) async {
    final pending = notifications.where((n) {
      final map = Map<String, dynamic>.from(n as Map);
      final status = (map['status'] ?? '').toString().toUpperCase();
      final provider = (map['provider_message_id'] ?? '').toString();
      return status == 'PENDING' &&
          (provider == 'DEVICE_PENDING' || provider.startsWith('DEVICE_'));
    }).toList();

    if (pending.isEmpty) return;

    final recipients = pending.map((n) {
      final map = Map<String, dynamic>.from(n as Map);
      return {
        'notificationId': map['id'],
        'contactId': map['contact_id'],
        'contactName': map['contact_name'],
        'contactPhone': map['contact_phone'],
        'dispatchPhone': normalizePhoneNumber(map['contact_phone']?.toString()),
        'simulateOnly': false,
      };
    }).toList();

    await dispatchDeviceSmsPayload(
      sosId: sosId,
      deviceSms: {
        'messageBody': messageBody,
        'recipients': recipients,
      },
    );
  }

  Future<void> _reportAllFailed(
    String sosId,
    List<dynamic> recipients,
    String error,
  ) async {
    final results = recipients.map((raw) {
      final r = Map<String, dynamic>.from(raw as Map);
      return {
        'notificationId': r['notificationId'],
        'status': 'FAILED',
        'errorMessage': error,
      };
    }).toList();
    await _reportResults(sosId, results);
  }

  Future<void> _reportResults(
    String sosId,
    List<Map<String, dynamic>> results,
  ) async {
    if (results.isEmpty) return;
    try {
      final token = await AuthService().getToken();
      if (token == null || token.isEmpty) return;

      final url = Uri.parse('${ApiConfig.baseUrl}/sos/$sosId/device-sms/results');
      await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'results': results}),
          )
          .timeout(const Duration(seconds: 12));
    } catch (e) {
      debugPrint('[SOS SMS] Failed to report results to backend: $e');
    }
  }
}
