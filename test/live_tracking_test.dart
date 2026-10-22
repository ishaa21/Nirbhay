import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:nirbhay/models/journey_model.dart';
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

  group('JourneyModel Unit Tests', () {
    test('JourneyModel fromJson and toJson', () {
      final now = DateTime.now();
      final json = {
        'id': 'journey-123',
        'user_id': 'user-456',
        'status': 'ACTIVE',
        'destination': 'Home',
        'tracking_token': 'token-abc-123',
        'tracking_url': 'https://nirbhay-9d5i.onrender.com/track/token-abc-123',
        'start_latitude': '28.6139',
        'start_longitude': '77.2090',
        'last_known_latitude': '28.6145',
        'last_known_longitude': '77.2095',
        'route_deviation_enabled': true,
        'deviation_threshold_meters': 150,
        'started_at': now.toIso8601String(),
        'ended_at': null,
      };

      final model = JourneyModel.fromJson(json);

      expect(model.id, 'journey-123');
      expect(model.userId, 'user-456');
      expect(model.status, 'ACTIVE');
      expect(model.isActive, isTrue);
      expect(model.destination, 'Home');
      expect(model.trackingToken, 'token-abc-123');
      expect(model.trackingUrl, 'https://nirbhay-9d5i.onrender.com/track/token-abc-123');
      expect(model.startLatitude, 28.6139);
      expect(model.startLongitude, 77.2090);
      expect(model.lastKnownLatitude, 28.6145);
      expect(model.lastKnownLongitude, 77.2095);
      expect(model.routeDeviationEnabled, isTrue);
      expect(model.deviationThresholdMeters, 150);

      final outJson = model.toJson();
      expect(outJson['id'], 'journey-123');
      expect(outJson['status'], 'ACTIVE');
      expect(outJson['destination'], 'Home');
    });

    test('JourneyModel state helpers', () {
      final active = JourneyModel(
        id: '1',
        userId: 'u',
        status: 'ACTIVE',
        trackingToken: 'tok',
        routeDeviationEnabled: true,
        deviationThresholdMeters: 150,
        startedAt: DateTime.now(),
      );
      expect(active.isActive, isTrue);

      final completed = JourneyModel(
        id: '2',
        userId: 'u',
        status: 'COMPLETED',
        trackingToken: 'tok',
        routeDeviationEnabled: true,
        deviationThresholdMeters: 150,
        startedAt: DateTime.now(),
        endedAt: DateTime.now(),
      );
      expect(completed.isActive, isFalse);
    });
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
      expect(find.text('Share Live Link'), findsOneWidget);
      expect(find.text('Start Journey & Share'), findsOneWidget);

      // Verify OpenStreetMap interactive widget is rendered immediately
      expect(find.byType(FlutterMap), findsOneWidget);
    });
  });
}
