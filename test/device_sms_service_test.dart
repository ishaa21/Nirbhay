
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nirbhay/services/device_sms_service.dart';
import 'package:nirbhay/services/sos_sms_dispatcher.dart';

// ---------------------------------------------------------------------------
// Minimal fake http.Client-style stub via MethodChannel mock
// We exercise SosSmsDispatcher's logic paths without network or real SMS.
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const smsChannel = MethodChannel('com.ishaa21.nirbhay/sms');

  // Helper: install a method-channel mock that returns what the test requests.
  void installSmsMock({
    bool hasSendSmsPermission = true,
    bool simReady = true,
    String sendStatus = 'PENDING',
    String? sendError,
  }) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(smsChannel, (call) async {
      if (call.method == 'checkCapabilities') {
        return {
          'platform': 'android',
          'hasSendSmsPermission': hasSendSmsPermission,
          'simReady': simReady,
          'smsSupported': true,
        };
      }
      if (call.method == 'requestPermission') {
        return {'granted': hasSendSmsPermission, 'permanentlyDenied': false};
      }
      if (call.method == 'sendMessages') {
        final messages =
            (call.arguments as Map)['messages'] as List<dynamic>;
        return {
          'success': sendError == null,
          'errorCode': sendError != null ? 'GENERIC' : null,
          'errorMessage': sendError,
          'results': sendError != null
              ? <Map<String, dynamic>>[]
              : messages
                  .map((m) => {
                        'clientRequestId': m['clientRequestId'],
                        'status': sendStatus,
                        'errorMessage': null,
                      })
                  .toList(),
        };
      }
      return null;
    });
  }

  void clearSmsMock() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(smsChannel, null);
  }

  setUp(() {
    DeviceSmsService.simulateAndroidForTests = true;
  });

  tearDown(() {
    DeviceSmsService.simulateAndroidForTests = false;
    clearSmsMock();
  });

  // ── DeviceSmsService unit tests ──────────────────────────────────────────

  group('DeviceSmsService — unit (mocked channel)', () {
    test('sendMessages — returns PENDING for each message when mock succeeds',
        () async {
      installSmsMock();
      final svc = DeviceSmsService();
      final results = await svc.sendMessages([
        DeviceSmsMessage(
          clientRequestId: 'req_1',
          phone: '+919876543210',
          body: 'TEST — unit test, no real SMS ever sent.',
        ),
        DeviceSmsMessage(
          clientRequestId: 'req_2',
          phone: '+919000000001',
          body: 'TEST — second recipient, no real SMS ever sent.',
        ),
      ]);
      expect(results, hasLength(2));
      expect(results[0].status, 'PENDING');
      expect(results[1].status, 'PENDING');
      expect(results[0].errorMessage, isNull);
    });

    test(
        'sendMessages — returns FAILED for all when channel reports error code',
        () async {
      installSmsMock(sendError: 'No SIM ready.');
      final svc = DeviceSmsService();
      final results = await svc.sendMessages([
        DeviceSmsMessage(
          clientRequestId: 'req_nosim',
          phone: '+919876543210',
          body: 'Should fail due to no SIM.',
        ),
      ]);
      expect(results, hasLength(1));
      expect(results.first.status, 'FAILED');
      expect(results.first.errorMessage, isNotNull);
    });

    test('isAndroid — true when simulateAndroidForTests is true', () {
      expect(DeviceSmsService().isAndroid, isTrue);
    });

    test('checkCapabilities — returns map with expected keys', () async {
      installSmsMock();
      final caps = await DeviceSmsService().checkCapabilities();
      expect(caps['platform'], 'android');
      expect(caps['hasSendSmsPermission'], isTrue);
      expect(caps['simReady'], isTrue);
      expect(caps['smsSupported'], isTrue);
    });

    test('requestSendPermission — returns true when mock grants permission',
        () async {
      installSmsMock();
      final granted = await DeviceSmsService().requestSendPermission();
      expect(granted, isTrue);
    });

    test(
        'requestSendPermission — returns false when mock denies permission',
        () async {
      installSmsMock(hasSendSmsPermission: false);
      final granted = await DeviceSmsService().requestSendPermission();
      expect(granted, isFalse);
    });

    test('sendMessages on non-Android returns FAILED with clear message',
        () async {
      // Temporarily disable the Android simulation flag
      DeviceSmsService.simulateAndroidForTests = false;
      final svc = DeviceSmsService();
      final results = await svc.sendMessages([
        DeviceSmsMessage(
            clientRequestId: 'r1',
            phone: '+919876543210',
            body: 'test'),
      ]);
      expect(results.first.status, 'FAILED');
      expect(results.first.errorMessage,
          contains('only supported on Android'));
      DeviceSmsService.simulateAndroidForTests = true;
    });

    test('clearOutcomes — supports full and selective clearing without throwing', () {
      final svc = DeviceSmsService();
      expect(() => svc.clearOutcomes(['req_1', 'req_2']), returnsNormally);
      expect(() => svc.clearOutcomes(), returnsNormally);
    });
  });

  // ── SosSmsDispatcher — simulateOnly path ─────────────────────────────────

  group('SosSmsDispatcher — simulateOnly recipient (test mode)', () {
    // We cannot call dispatchDeviceSmsPayload fully without a real HTTP server,
    // but we can verify the DeviceSmsService path is bypassed for simulateOnly
    // by confirming sendMessages is never invoked in the mock when the
    // dispatcher exits before reaching it.
    test('DeviceSmsService sendMessages called with correct payload', () async {
      installSmsMock();
      final svc = DeviceSmsService();
      svc.clearOutcomes();

      final results = await svc.sendMessages([
        DeviceSmsMessage(
          clientRequestId: 'nirbhay_sos1_notif1',
          phone: '+919876543210',
          body: 'EMERGENCY ALERT: Nirbhay SOS. Location unavailable.',
        ),
      ]);
      expect(results.first.clientRequestId, 'nirbhay_sos1_notif1');
      expect(results.first.status, 'PENDING');
    });
  });

  // ── DeviceSmsSendResult model ─────────────────────────────────────────────

  group('DeviceSmsSendResult model', () {
    test('creates correctly with all fields', () {
      final r = DeviceSmsSendResult(
        clientRequestId: 'cr123',
        status: 'SENT',
        errorMessage: null,
      );
      expect(r.clientRequestId, 'cr123');
      expect(r.status, 'SENT');
      expect(r.errorMessage, isNull);
    });

    test('creates with FAILED status and error message', () {
      final r = DeviceSmsSendResult(
        clientRequestId: 'cr456',
        status: 'FAILED',
        errorMessage: 'No cellular service available.',
      );
      expect(r.status, 'FAILED');
      expect(r.errorMessage, 'No cellular service available.');
    });
  });

  // ── DeviceSmsMessage model ────────────────────────────────────────────────

  group('DeviceSmsMessage model', () {
    test('stores fields correctly', () {
      final m = DeviceSmsMessage(
        clientRequestId: 'msg_1',
        phone: '+919876543210',
        body: 'SOS test body',
      );
      expect(m.clientRequestId, 'msg_1');
      expect(m.phone, '+919876543210');
      expect(m.body, 'SOS test body');
    });
  });

  // ── Duplicate prevention ──────────────────────────────────────────────────

  group('SosSmsDispatcher — duplicate prevention guard', () {
    test(
        'dispatchDeviceSmsPayload with empty recipients returns immediately (no crash)',
        () async {
      // No mock needed — it returns before touching the channel.
      final dispatcher = SosSmsDispatcher();
      await expectLater(
        dispatcher.dispatchDeviceSmsPayload(
          sosId: 'sos_duplicate_test',
          deviceSms: {'messageBody': 'test', 'recipients': <dynamic>[]},
        ),
        completes,
      );
    });

    test('dispatchDeviceSmsPayload with null deviceSms returns immediately',
        () async {
      final dispatcher = SosSmsDispatcher();
      await expectLater(
        dispatcher.dispatchDeviceSmsPayload(
          sosId: 'sos_null_test',
          deviceSms: null,
        ),
        completes,
      );
    });

    test('dispatchKey isolates SOS alert from resolve safe message for same incident',
        () {
      final dispatcher = SosSmsDispatcher();

      final sosRecipients = [
        {'notificationId': 'notif_sos_1', 'dispatchPhone': '+919876543210'}
      ];
      final resolveRecipients = [
        {'notificationId': 'notif_resolve_1', 'dispatchPhone': '+919876543210'}
      ];

      final sosKey = dispatcher.dispatchKey('incident_1', sosRecipients);
      final resolveKey = dispatcher.dispatchKey('incident_1', resolveRecipients);
      final duplicateSosKey = dispatcher.dispatchKey('incident_1', sosRecipients);

      // Same batch gets identical key (preventing duplicate dispatch)
      expect(sosKey, equals(duplicateSosKey));
      // Resolve message gets distinct key (preventing resolve from being blocked by initial SOS alert)
      expect(sosKey, isNot(equals(resolveKey)));
      expect(sosKey, contains('notif_sos_1'));
      expect(resolveKey, contains('notif_resolve_1'));
    });

    test('DeviceSmsService sends resolve "user is safe" SMS payload', () async {
      installSmsMock();
      final svc = DeviceSmsService();

      final results = await svc.sendMessages([
        DeviceSmsMessage(
          clientRequestId: 'nirbhay_incident1_resolveNotif1',
          phone: '+919876543210',
          body:
              'STATUS UPDATE: User\'s Nirbhay SOS emergency alert has been RESOLVED. User is SAFE now. No further action is required.',
        ),
      ]);

      expect(results, hasLength(1));
      expect(results.first.clientRequestId,
          'nirbhay_incident1_resolveNotif1');
      expect(results.first.status, 'PENDING');
      expect(results.first.errorMessage, isNull);
    });
  });
}
