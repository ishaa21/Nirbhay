import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nirbhay/models/emergency_contact_model.dart';
import 'package:nirbhay/services/device_sms_service.dart';
import 'package:nirbhay/services/sos_service.dart';
import 'package:nirbhay/services/sos_sms_dispatcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const smsChannel = MethodChannel('com.ishaa21.nirbhay/sms');
  const geolocatorChannel = MethodChannel('flutter.baseflow.com/geolocator');
  const storageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  final List<DeviceSmsMessage> capturedMessages = [];
  final Map<String, String> mockStorage = {};

  void installMocks({
    bool hasSendSmsPermission = true,
    bool simReady = true,
    double? mockLat = 22.2500,
    double? mockLng = 73.2000,
  }) {
    capturedMessages.clear();
    mockStorage.clear();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async {
      if (call.method == 'read') {
        return mockStorage[call.arguments['key']];
      }
      if (call.method == 'write') {
        mockStorage[call.arguments['key']] = call.arguments['value']?.toString() ?? '';
        return null;
      }
      if (call.method == 'delete') {
        mockStorage.remove(call.arguments['key']);
        return null;
      }
      if (call.method == 'deleteAll') {
        mockStorage.clear();
        return null;
      }
      return null;
    });

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
        final messages = (call.arguments as Map)['messages'] as List<dynamic>;
        for (final m in messages) {
          capturedMessages.add(DeviceSmsMessage(
            clientRequestId: m['clientRequestId'],
            phone: m['phone'],
            body: m['body'],
          ));
        }
        return {
          'success': true,
          'results': messages
              .map((m) => {
                    'clientRequestId': m['clientRequestId'],
                    'status': 'PENDING',
                    'errorMessage': null,
                  })
              .toList(),
        };
      }
      return null;
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(geolocatorChannel, (call) async {
      if (call.method == 'isLocationServiceEnabled') return true;
      if (call.method == 'checkPermission' || call.method == 'requestPermission') {
        return 3; // LocationPermission.always
      }
      if (call.method == 'getCurrentPosition' || call.method == 'getLastKnownPosition') {
        if (mockLat != null && mockLng != null) {
          return {
            'latitude': mockLat,
            'longitude': mockLng,
            'timestamp': DateTime(2026, 10, 23, 10, 45, 0).millisecondsSinceEpoch,
            'accuracy': 10.0,
            'altitude': 0.0,
            'heading': 0.0,
            'speed': 0.0,
            'speed_accuracy': 0.0,
          };
        }
        return null;
      }
      return null;
    });
  }

  void clearMocks() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(smsChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(geolocatorChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  }

  setUp(() {
    DeviceSmsService.simulateAndroidForTests = true;
    SosSmsDispatcher().clearDispatchedSessions();
    SosService().clearActiveOfflineIncident();
    installMocks();
  });

  tearDown(() {
    DeviceSmsService.simulateAndroidForTests = false;
    SosSmsDispatcher().clearDispatchedSessions();
    SosService().clearActiveOfflineIncident();
    clearMocks();
  });

  group('Requirement 3, 4, 5, 6 — Location & SMS Alert Message Formatting', () {
    test('buildAlertMessage includes fresh GPS coordinates and Google Maps link', () {
      final now = DateTime(2026, 10, 23, 10, 45, 0);
      final loc = SosLocationResult(
        latitude: 22.2500,
        longitude: 73.2000,
        isLastKnown: false,
        timestamp: now,
      );

      final msg = SosService.buildAlertMessage(activatedAt: now, location: loc);

      expect(msg, contains('EMERGENCY ALERT: Nirbhay SOS activated at'));
      expect(msg, contains('https://maps.google.com/?q=22.25,73.2'));
      expect(msg, contains('(22.2500, 73.2000)'));
      expect(msg, isNot(contains('LAST KNOWN LOCATION')));
      expect(msg, contains('Please check immediately.'));
    });

    test('buildAlertMessage includes LAST KNOWN LOCATION tag and timestamp when using fallback fix', () {
      final now = DateTime(2026, 10, 23, 10, 50, 0);
      final lastKnownTime = DateTime(2026, 10, 23, 10, 30, 0);
      final loc = SosLocationResult(
        latitude: 19.0760,
        longitude: 72.8777,
        isLastKnown: true,
        timestamp: lastKnownTime,
      );

      final msg = SosService.buildAlertMessage(activatedAt: now, location: loc);

      expect(msg, contains('EMERGENCY ALERT: Nirbhay SOS activated at'));
      expect(msg, contains('https://maps.google.com/?q=19.076,72.8777'));
      expect(msg, contains('(19.0760, 72.8777)'));
      expect(msg, contains('[LAST KNOWN LOCATION as of'));
      expect(msg, contains('Please check immediately.'));
    });

    test('buildAlertMessage sends without coordinates when location is unavailable (does not block)', () {
      final now = DateTime(2026, 10, 23, 10, 45, 0);
      const loc = SosLocationResult(
        latitude: null,
        longitude: null,
        isLastKnown: false,
        timestamp: null,
      );

      final msg = SosService.buildAlertMessage(activatedAt: now, location: loc);

      expect(msg, contains('EMERGENCY ALERT: Nirbhay SOS activated at'));
      expect(msg, contains('Location: Unavailable.'));
      expect(msg, contains('Please check immediately.'));
    });
  });

  group('Requirement 1 & 2 — Direct SIM-SMS Dispatch Without Internet', () {
    test('dispatchDirectSms transmits native SIM SMS to emergency contacts', () async {
      final contacts = [
        EmergencyContactModel(
          id: 'c1',
          userId: 'u1',
          name: 'Mom',
          phone: '+919876543210',
          autoAlert: true,
        ),
        EmergencyContactModel(
          id: 'c2',
          userId: 'u1',
          name: 'Brother',
          phone: '9876500000',
          autoAlert: true,
        ),
      ];

      final result = await SosSmsDispatcher().dispatchDirectSms(
        sosId: 'test_offline_sos_1',
        contacts: contacts,
        messageBody: 'EMERGENCY ALERT: Nirbhay SOS activated. Location: https://maps.google.com/?q=22.25,73.2',
      );

      expect(result['success'], isTrue);
      expect(result['status'], 'DISPATCHED');
      expect(result['recipientsCount'], 2);
      expect(capturedMessages, hasLength(2));
      expect(capturedMessages[0].phone, '+919876543210');
      expect(capturedMessages[1].phone, '+919876500000');
      expect(capturedMessages[0].body, contains('EMERGENCY ALERT: Nirbhay SOS activated.'));
    });

    test('dispatchDirectSms handles empty contacts list without crashing', () async {
      final result = await SosSmsDispatcher().dispatchDirectSms(
        sosId: 'test_offline_sos_empty',
        contacts: [],
        messageBody: 'Test alert',
      );

      expect(result['success'], isFalse);
      expect(result['status'], 'NO_CONTACTS');
      expect(capturedMessages, isEmpty);
    });
  });

  group('Requirement 8 — Duplicate SMS Prevention Guard', () {
    test('Prevents sending second SMS alert for the same SOS session', () async {
      final contacts = [
        EmergencyContactModel(
          id: 'c1',
          userId: 'u1',
          name: 'Guardian',
          phone: '+919876543210',
          autoAlert: true,
        ),
      ];

      // First dispatch succeeds
      final firstRes = await SosSmsDispatcher().dispatchDirectSms(
        sosId: 'sos_dedup_1',
        contacts: contacts,
        messageBody: 'EMERGENCY ALERT: Initial dispatch.',
      );
      expect(firstRes['status'], 'DISPATCHED');
      expect(capturedMessages, hasLength(1));

      // Second dispatch with same sosId is deduplicated
      final secondRes = await SosSmsDispatcher().dispatchDirectSms(
        sosId: 'sos_dedup_1',
        contacts: contacts,
        messageBody: 'EMERGENCY ALERT: Second attempt.',
      );
      expect(secondRes['status'], 'ALREADY_DISPATCHED');
      expect(capturedMessages, hasLength(1), reason: 'No second SMS should be sent');
    });

    test('linkIncidents prevents backend deviceSms from triggering duplicate dispatch', () async {
      final contacts = [
        EmergencyContactModel(
          id: 'c1',
          userId: 'u1',
          name: 'Guardian',
          phone: '+919876543210',
          autoAlert: true,
        ),
      ];

      // 1. Initial direct SIM dispatch with local ID
      await SosSmsDispatcher().dispatchDirectSms(
        sosId: 'local_incident_100',
        contacts: contacts,
        messageBody: 'EMERGENCY ALERT: Nirbhay SOS.',
      );
      expect(capturedMessages, hasLength(1));

      // 2. Backend later returns server incident ID 'backend_uuid_200'
      SosSmsDispatcher().linkIncidents('local_incident_100', 'backend_uuid_200');

      // 3. Backend deviceSms payload arrives for 'backend_uuid_200'
      await SosSmsDispatcher().dispatchDeviceSmsPayload(
        sosId: 'backend_uuid_200',
        deviceSms: {
          'messageBody': 'EMERGENCY ALERT: Nirbhay SOS.',
          'recipients': [
            {
              'notificationId': 'server_notif_1',
              'dispatchPhone': '+919876543210',
              'simulateOnly': false,
            }
          ],
        },
      );

      // Captured messages remains 1 (duplicate avoided!)
      expect(capturedMessages, hasLength(1), reason: 'Linked incident must not dispatch duplicate SMS');
    });

    test('Resolution "User is safe now" SMS is NOT blocked by alert deduplication', () async {
      final contacts = [
        EmergencyContactModel(
          id: 'c1',
          userId: 'u1',
          name: 'Guardian',
          phone: '+919876543210',
          autoAlert: true,
        ),
      ];

      // 1. Dispatch initial SOS alert
      await SosSmsDispatcher().dispatchDirectSms(
        sosId: 'incident_res_test',
        contacts: contacts,
        messageBody: 'EMERGENCY ALERT: In danger.',
      );
      expect(capturedMessages, hasLength(1));

      // 2. Dispatch resolution message for same incident
      await SosSmsDispatcher().dispatchDeviceSmsPayload(
        sosId: 'incident_res_test',
        deviceSms: {
          'messageBody': 'STATUS UPDATE: User is SAFE now.',
          'recipients': [
            {
              'notificationId': 'resolve_notif_1',
              'dispatchPhone': '+919876543210',
              'simulateOnly': false,
            }
          ],
        },
      );

      // Total captured messages is now 2 (1 alert + 1 safe update)
      expect(capturedMessages, hasLength(2));
      expect(capturedMessages[1].body, contains('User is SAFE now.'));
    });
  });

  group('Requirement 10 — Honest Permission and Hardware Checks', () {
    test('Returns NOT_ANDROID honestly when run on non-Android platform', () async {
      DeviceSmsService.simulateAndroidForTests = false;
      final contacts = [
        EmergencyContactModel(
          id: 'c1',
          userId: 'u1',
          name: 'Friend',
          phone: '+919876543210',
          autoAlert: true,
        ),
      ];

      final res = await SosSmsDispatcher().dispatchDirectSms(
        sosId: 'non_android_sos',
        contacts: contacts,
        messageBody: 'Test alert',
      );

      expect(res['success'], isFalse);
      expect(res['status'], 'NOT_ANDROID');
      expect(capturedMessages, isEmpty);
      DeviceSmsService.simulateAndroidForTests = true;
    });
  });

  group('Requirement 1, 7, 8 — Full SosService Offline End-to-End Flow', () {
    test('createSos dispatches direct SMS offline and creates active incident', () async {
      // 1. Preload local cached emergency contacts
      final contacts = [
        EmergencyContactModel(
          id: 'c_offline_1',
          userId: 'u1',
          name: 'Dad',
          phone: '+919876543210',
          autoAlert: true,
        ),
      ];
      mockStorage['nirbhay_cached_emergency_contacts'] = jsonEncode(
        contacts.map((c) => c.toJson()).toList(),
      );

      // 2. Invoke createSos without internet/backend
      final res = await SosService().createSos();

      expect(res['success'], isTrue);
      expect(res['offline'], isTrue);
      expect(res['smsDispatched'], isTrue);
      expect(res['incident'], isNotNull);
      expect(SosService().activeOfflineIncident, isNotNull);
      expect(SosService().activeOfflineIncident!.isActive, isTrue);

      // Verify SMS was dispatched via direct Android SIM SMS
      expect(capturedMessages, hasLength(1));
      expect(capturedMessages.first.phone, '+919876543210');
      expect(capturedMessages.first.body, contains('EMERGENCY ALERT: Nirbhay SOS activated at'));
      expect(capturedMessages.first.body, contains('https://maps.google.com/?q=22.25,73.2'));

      // 3. Attempting duplicate createSos returns alreadyActive
      final dupRes = await SosService().createSos();
      expect(dupRes['success'], isFalse);
      expect(dupRes['alreadyActive'], isTrue);
      expect(capturedMessages, hasLength(1), reason: 'Duplicate SOS must not send another SMS');

      // 4. Resolving offline incident dispatches safe update and clears incident
      final resolveRes = await SosService().resolveSos(res['incident'].id);
      expect(resolveRes['success'], isTrue);
      expect(SosService().activeOfflineIncident, isNull);
      expect(capturedMessages, hasLength(2));
      expect(capturedMessages[1].body, contains('User is SAFE now.'));
    });
  });
}
