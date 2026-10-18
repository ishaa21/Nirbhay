import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nirbhay/services/shake_sos_service.dart';
import 'package:nirbhay/widgets/shake_countdown_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('com.ishaa21.nirbhay/shake_sos');
  int sosTriggerCount = 0;
  bool mockServiceRunning = false;
  String mockSensitivity = 'DEFAULT';
  Map<String, dynamic> mockCountdownState = {'isActive': false, 'remainingSeconds': 0};

  void setupMockChannels() {
    sosTriggerCount = 0;
    mockServiceRunning = false;
    mockSensitivity = 'DEFAULT';
    mockCountdownState = {'isActive': false, 'remainingSeconds': 0};

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
      switch (call.method) {
        case 'isServiceEnabled':
          return mockServiceRunning;
        case 'startService':
          mockServiceRunning = true;
          return true;
        case 'stopService':
          mockServiceRunning = false;
          return true;
        case 'cancelCountdown':
          mockCountdownState = {'isActive': false, 'remainingSeconds': 0};
          return true;
        case 'getCountdownState':
          return mockCountdownState;
        case 'setSensitivity':
          mockSensitivity = (call.arguments as Map)['sensitivity'] as String? ?? 'DEFAULT';
          return true;
        default:
          return null;
      }
    });
  }

  void tearDownMockChannels() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
  }

  setUp(() {
    ShakeSosService.simulateForTests = true;
    setupMockChannels();
    ShakeSosService().onSosTrigger = () async {
      sosTriggerCount++;
      return {'success': true, 'incident': {'id': 'test-sos-123'}};
    };
  });

  tearDown(() {
    ShakeSosService.simulateForTests = false;
    ShakeSosService().onSosTrigger = null;
    tearDownMockChannels();
  });

  group('ShakeSosService - Service Lifecycle & Configuration', () {
    test('isServiceEnabled reflects native service status', () async {
      mockServiceRunning = false;
      expect(await ShakeSosService().isServiceEnabled(), isFalse);

      mockServiceRunning = true;
      expect(await ShakeSosService().isServiceEnabled(), isTrue);
    });

    test('startShakeService starts background foreground service', () async {
      final success = await ShakeSosService().startShakeService();
      expect(success, isTrue);
      expect(mockServiceRunning, isTrue);
    });

    test('stopShakeService stops background foreground service', () async {
      await ShakeSosService().startShakeService();
      final success = await ShakeSosService().stopShakeService();
      expect(success, isTrue);
      expect(mockServiceRunning, isFalse);
    });

    test('setSensitivity updates native threshold preset', () async {
      final success = await ShakeSosService().setSensitivity('HIGH');
      expect(success, isTrue);
      expect(mockSensitivity, 'HIGH');
    });

    test('getCountdownState retrieves persisted countdown data', () async {
      mockCountdownState = {'isActive': true, 'remainingSeconds': 12};
      final state = await ShakeSosService().getCountdownState();
      expect(state['isActive'], isTrue);
      expect(state['remainingSeconds'], 12);
    });
  });

  group('ShakeSosService - Authoritative Cancellation & Expiry', () {
    test('Shake detected in foreground or background starts countdown event', () async {
      ShakeSosEvent? capturedEvent;
      final sub = ShakeSosService().shakeEvents.listen((e) {
        capturedEvent = e;
      });

      ShakeSosService().simulateEvent(
        ShakeSosEvent(
          type: ShakeSosEventType.countdownStarted,
          remainingSeconds: 15,
        ),
      );

      await Future.delayed(Duration.zero);
      expect(capturedEvent, isNotNull);
      expect(capturedEvent!.type, ShakeSosEventType.countdownStarted);
      expect(capturedEvent!.remainingSeconds, 15);
      expect(sosTriggerCount, 0); // No SOS on start

      await sub.cancel();
    });

    test('Countdown cancellation at 14s authoritatively prevents SOS dispatch', () async {
      ShakeSosEvent? lastEvent;
      final sub = ShakeSosService().shakeEvents.listen((e) {
        lastEvent = e;
      });

      // 1. Shake detected -> 15s
      ShakeSosService().simulateEvent(
        ShakeSosEvent(type: ShakeSosEventType.countdownStarted, remainingSeconds: 15),
      );

      // 2. 1 second elapsed -> 14s tick
      ShakeSosService().simulateEvent(
        ShakeSosEvent(type: ShakeSosEventType.countdownTick, remainingSeconds: 14),
      );

      // 3. User cancels countdown at 14 seconds
      final cancelled = await ShakeSosService().cancelCountdown();
      expect(cancelled, isTrue);

      await Future.delayed(Duration.zero);
      expect(lastEvent, isNotNull);
      expect(lastEvent!.type, ShakeSosEventType.countdownCancelled);
      expect(sosTriggerCount, 0, reason: 'Cancelled countdown must NEVER trigger SOS');

      await sub.cancel();
    });

    test('Countdown expiry after 15s triggers SOS workflow exactly once', () async {
      ShakeSosEvent? lastEvent;
      final sub = ShakeSosService().shakeEvents.listen((e) {
        lastEvent = e;
      });

      ShakeSosService().simulateEvent(
        ShakeSosEvent(type: ShakeSosEventType.countdownExpired, remainingSeconds: 0),
      );

      await Future.delayed(Duration.zero);
      expect(lastEvent, isNotNull);
      expect(lastEvent!.type, ShakeSosEventType.countdownExpired);
      expect(sosTriggerCount, 1, reason: 'Expired countdown must trigger SOS exactly once');

      await sub.cancel();
    });

    test('Repeated shakes during active countdown are deduplicated (no multiple SOS)', () async {
      // Simulate multiple shake/expiry events firing concurrently
      final futures = [
        ShakeSosService().handleCountdownExpired(),
        ShakeSosService().handleCountdownExpired(),
        ShakeSosService().handleCountdownExpired(),
      ];

      await Future.wait(futures);
      expect(sosTriggerCount, 1, reason: 'Duplicate triggers must be deduplicated to exactly 1 SOS incident');
    });

    test('App restoration / activity recreation during countdown recovers active state', () async {
      mockCountdownState = {'isActive': true, 'remainingSeconds': 9};
      final state = await ShakeSosService().getCountdownState();

      expect(state['isActive'], isTrue);
      expect(state['remainingSeconds'], 9);
      // App can safely present ShakeCountdownDialog with 9 seconds remaining
    });
  });

  group('ShakeCountdownDialog - Widget Tests', () {
    testWidgets('renders 15s countdown and cancel button', (tester) async {
      bool cancelTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShakeCountdownDialog(
              initialSeconds: 15,
              onCancelled: () {
                cancelTapped = true;
              },
            ),
          ),
        ),
      );

      // Verify emergency header and countdown text
      expect(find.text('SHAKE DETECTED'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      expect(find.text('SECONDS'), findsOneWidget);
      expect(find.text('CANCEL SOS (I AM SAFE)'), findsOneWidget);

      // Tap Cancel button
      await tester.tap(find.text('CANCEL SOS (I AM SAFE)'));
      await tester.pump();

      expect(cancelTapped, isTrue);
      expect(sosTriggerCount, 0);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('updates remaining seconds on countdown ticks', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShakeCountdownDialog(
              initialSeconds: 15,
            ),
          ),
        ),
      );

      expect(find.text('15'), findsOneWidget);

      // Simulate native countdown tick to 10 seconds
      ShakeSosService().simulateEvent(
        ShakeSosEvent(type: ShakeSosEventType.countdownTick, remainingSeconds: 10),
      );

      await tester.pump();
      expect(find.text('10'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
