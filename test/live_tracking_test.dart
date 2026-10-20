import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nirbhay/services/location_update_service.dart';
import 'package:nirbhay/screens/live_tracking_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel geolocatorChannel = MethodChannel('flutter.baseflow.com/geolocator');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      geolocatorChannel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'isLocationServiceEnabled') {
          return true;
        }
        if (methodCall.method == 'checkPermission' || methodCall.method == 'requestPermission') {
          return 3; // LocationPermission.always
        }
        if (methodCall.method == 'getLastKnownPosition' || methodCall.method == 'getCurrentPosition') {
          return {
            'latitude': 22.2500,
            'longitude': 73.2000,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'accuracy': 15.0,
            'altitude': 0.0,
            'heading': 0.0,
            'speed': 0.0,
            'speed_accuracy': 0.0,
          };
        }
        return null;
      },
    );
  });

  group('LocationUpdateService Unit Tests', () {
    late LocationUpdateService service;

    setUp(() {
      service = LocationUpdateService();
      service.stop();
    });

    tearDown(() {
      service.stop();
    });

    test('Initial state after stop is not running', () {
      expect(service.isRunning, isFalse);
      expect(service.state, equals(TrackingState.stopped));
      expect(service.activeSosId, isNull);
      expect(service.activeJourneyId, isNull);
      expect(service.queuedOfflineUpdatesCount, equals(0));
    });

    test('Calling start without ids does nothing', () async {
      await service.start();
      expect(service.isRunning, isFalse);
      expect(service.state, equals(TrackingState.stopped));
    });

    test('Status notifier reports state changes and tracks active SOS id', () async {
      final states = <TrackingState>[];
      service.statusNotifier.addListener(() {
        states.add(service.statusNotifier.value.state);
      });

      // Starting with SOS id
      await service.startSos('sos-test-uuid-1234');
      expect(service.isRunning, isTrue);
      expect(service.activeSosId, equals('sos-test-uuid-1234'));

      service.stop();
      expect(service.isRunning, isFalse);
      expect(service.state, equals(TrackingState.stopped));
      expect(states, contains(TrackingState.stopped));
    });

    test('TrackingStatus isStale calculation works', () {
      final fresh = TrackingStatus(
        state: TrackingState.tracking,
        lastSuccessfulUploadTime: DateTime.now().subtract(const Duration(seconds: 10)),
      );
      expect(fresh.isStale, isFalse);

      final stale = TrackingStatus(
        state: TrackingState.tracking,
        lastSuccessfulUploadTime: DateTime.now().subtract(const Duration(seconds: 75)),
      );
      expect(stale.isStale, isTrue);

      final noTime = const TrackingStatus(
        state: TrackingState.idle,
        lastSuccessfulUploadTime: null,
      );
      expect(noTime.isStale, isFalse);
    });

    test('Stop clears active session and stops running', () async {
      await service.startSos('sos-test-uuid-9999');
      expect(service.isRunning, isTrue);

      service.stop();
      expect(service.isRunning, isFalse);
      expect(service.activeSosId, isNull);
      expect(service.activeJourneyId, isNull);
      expect(service.state, equals(TrackingState.stopped));
      expect(service.queuedOfflineUpdatesCount, equals(0));
    });
  });

  group('LiveTrackingScreen Widget Tests', () {
    setUp(() {
      LocationUpdateService().stop();
    });

    tearDown(() {
      LocationUpdateService().stop();
    });

    testWidgets('Renders LiveTrackingScreen structure and widgets without crashing', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: LiveTrackingScreen(),
        ),
      );

      // Allow initial async checks to pump
      await tester.pump();

      // Verify title & app bar
      expect(find.text('Nirbhay'), findsOneWidget);
      expect(find.text('Live Journey Tracking'), findsOneWidget);

      // Verify status banner and telemetry card
      expect(find.text('REAL-TIME TELEMETRY'), findsOneWidget);
      expect(find.text('Speed'), findsOneWidget);
      expect(find.text('GPS Accuracy'), findsOneWidget);
      expect(find.text('Last Sync'), findsOneWidget);

      // Verify action buttons
      expect(find.text('Google Maps'), findsOneWidget);
      expect(find.text('SOS'), findsOneWidget);
    });
  });
}
