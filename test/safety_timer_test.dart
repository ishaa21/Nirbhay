import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nirbhay/models/safety_timer_model.dart';
import 'package:nirbhay/screens/safety_timer_screen.dart';

void main() {
  group('SafetyTimerModel Unit Tests', () {
    test('SafetyTimerModel fromJson and toJson', () {
      final now = DateTime.now();
      final expires = now.add(const Duration(minutes: 15));
      final json = {
        'id': 'timer-123',
        'user_id': 'user-456',
        'status': 'ACTIVE',
        'duration_minutes': 15,
        'expires_at': expires.toIso8601String(),
        'latitude': 12.9716,
        'longitude': 77.5946,
        'location_at': now.toIso8601String(),
        'alert_fired': false,
        'created_at': now.toIso8601String(),
      };

      final model = SafetyTimerModel.fromJson(json);

      expect(model.id, 'timer-123');
      expect(model.userId, 'user-456');
      expect(model.status, 'ACTIVE');
      expect(model.isActive, isTrue);
      expect(model.isExpired, isFalse);
      expect(model.durationMinutes, 15);
      expect(model.latitude, 12.9716);
      expect(model.longitude, 77.5946);
      expect(model.alertFired, isFalse);

      final convertedJson = model.toJson();
      expect(convertedJson['id'], 'timer-123');
      expect(convertedJson['status'], 'ACTIVE');
      expect(convertedJson['duration_minutes'], 15);
    });

    test('SafetyTimerModel remainingSeconds calculation', () {
      final expires = DateTime.now().add(const Duration(seconds: 300));
      final model = SafetyTimerModel(
        id: 'timer-1',
        userId: 'u1',
        status: 'ACTIVE',
        durationMinutes: 5,
        expiresAt: expires,
        alertFired: false,
        createdAt: DateTime.now(),
      );

      // 1. With server remainingMs provided:
      expect(model.remainingSeconds(120000), 120);
      expect(model.remainingSeconds(0), 0);

      // 2. Fallback to local expiresAt:
      final localSec = model.remainingSeconds();
      expect(localSec, greaterThanOrEqualTo(295));
      expect(localSec, lessThanOrEqualTo(305));
    });

    test('SafetyTimerModel state transitions', () {
      final base = SafetyTimerModel(
        id: 'timer-1',
        userId: 'u1',
        status: 'ACTIVE',
        durationMinutes: 15,
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
        alertFired: false,
        createdAt: DateTime.now(),
      );

      final checkedIn = base.copyWith(status: 'CHECKED_IN');
      expect(checkedIn.isCheckedIn, isTrue);
      expect(checkedIn.isActive, isFalse);

      final cancelled = base.copyWith(status: 'CANCELLED');
      expect(cancelled.isCancelled, isTrue);
      expect(cancelled.isActive, isFalse);

      final expired = base.copyWith(status: 'EXPIRED', alertFired: true);
      expect(expired.isExpired, isTrue);
      expect(expired.alertFired, isTrue);
      expect(expired.isActive, isFalse);
    });
  });

  group('SafetyTimerScreen Widget Tests', () {
    testWidgets('Renders idle UI with all four selectable durations', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: SafetyTimerScreen(),
        ),
      );

      // 1. First frame: loading spinner while async init runs
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      // 2. Let the real async HTTP call run (it will fail — no server in test),
      //    then pump the result back into the widget tree.
      await tester.runAsync(() async {
        // Give the HTTP timeout time to expire (SafetyTimerService has 10s timeout)
        // In test environments, the socket will be refused immediately.
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      // Pump any pending microtasks/frames after the async call completes
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 3. Screen should now show idle state (network failed → no active timer)
      // The 'Safety Timer' title is rendered in the header
      expect(find.text('Safety Timer'), findsOneWidget);

      // Onboarding info card
      expect(find.text('How the Safety Timer Protects You'), findsOneWidget);

      // All four selectable duration chips present
      expect(find.text('5\nMIN'), findsOneWidget);
      expect(find.text('15\nMIN'), findsOneWidget);
      expect(find.text('30\nMIN'), findsOneWidget);
      expect(find.text('1\nHOUR'), findsOneWidget);

      // Start Timer button visible
      expect(find.text('Start Timer'), findsOneWidget);

      // The idle timer visual shows the default selected duration (30 MIN = 30:00)
      expect(find.text('30:00'), findsOneWidget);
    });
  });
}
