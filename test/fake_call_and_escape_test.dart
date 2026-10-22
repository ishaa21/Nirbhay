import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nirbhay/screens/fake_call_screen.dart';
import 'package:nirbhay/screens/quick_escape_screen.dart';

void main() {
  group('FakeCallScreen Unit & Widget Tests', () {
    test('CallerAvatarPreset configuration', () {
      expect(kCallerPresets.length, greaterThanOrEqualTo(5));
      expect(kCallerPresets.any((p) => p.label == 'Mom'), isTrue);
      expect(kCallerPresets.any((p) => p.label == 'Police'), isTrue);
      expect(kCallerPresets.any((p) => p.label == 'Boss'), isTrue);
    });

    testWidgets('Renders FakeCallScreen setup UI with customizable caller and delay chips', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: FakeCallScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Header
      expect(find.text('Fake Call Simulator'), findsOneWidget);

      // Caller Identity section
      expect(find.text('1. Caller Identity & Avatar'), findsOneWidget);
      expect(find.text('Mom'), findsWidgets);
      expect(find.text('Dad'), findsWidgets);
      expect(find.text('Boss'), findsWidgets);

      // Delay selectors
      expect(find.text('Now'), findsOneWidget);
      expect(find.text('10 sec'), findsOneWidget);
      expect(find.text('30 sec'), findsOneWidget);
      expect(find.text('60 sec'), findsOneWidget);
      expect(find.text('5 min'), findsOneWidget);

      // Android restriction explanation card
      expect(find.text('Android Background Restriction Info'), findsOneWidget);

      // Trigger button
      expect(find.text('Ring Phone Immediately'), findsOneWidget);
    });

    testWidgets('Customizing caller name and selecting delay updates trigger button label', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: FakeCallScreen(),
        ),
      );
      await tester.pump();

      // Select 10 sec delay
      await tester.tap(find.text('10 sec'));
      await tester.pump();

      expect(find.text('Arm Call (10s Delay)'), findsOneWidget);

      // Select 30 sec delay
      await tester.tap(find.text('30 sec'));
      await tester.pump();

      expect(find.text('Arm Call (30s Delay)'), findsOneWidget);

      // Select 5 min delay
      await tester.tap(find.text('5 min'));
      await tester.pump();

      expect(find.text('Arm Call (5 min Delay)'), findsOneWidget);

      // Tap preset 'Police'
      await tester.tap(find.text('Police'));
      await tester.pump();

      final state = tester.state<FakeCallScreenState>(find.byType(FakeCallScreen));
      expect(state.selectedPreset.label, 'Police');
      expect(state.callerNameController.text, 'Police Department');
    });

    testWidgets('Arming and cancelling a scheduled call', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: FakeCallScreen(),
        ),
      );
      await tester.pump();

      // Select 30 sec
      await tester.tap(find.text('30 sec'));
      await tester.pump();

      // Arm call
      await tester.tap(find.text('Arm Call (30s Delay)'));
      await tester.pump();

      // Armed progress card should be displayed
      expect(find.text('CANCEL SCHEDULED CALL'), findsOneWidget);
      final state = tester.state<FakeCallScreenState>(find.byType(FakeCallScreen));
      expect(state.isArmed, isTrue);

      // Cancel scheduled call
      await tester.tap(find.text('CANCEL SCHEDULED CALL'));
      await tester.pump();

      expect(state.isArmed, isFalse);
      expect(find.text('CANCEL SCHEDULED CALL'), findsNothing);
    });

    testWidgets('Immediate call triggers full simulated incoming overlay with Accept and Decline', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: FakeCallScreen(),
        ),
      );
      await tester.pump();

      // Ensure 'Now' is selected and trigger
      await tester.tap(find.text('Ring Phone Immediately'));
      await tester.pump();

      // Full screen overlay appears
      expect(find.text('SIMULATED CALL • NIRBHAY'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);

      // Tap Decline dismisses the call
      await tester.tap(find.text('Decline'));
      await tester.pump();

      final state = tester.state<FakeCallScreenState>(find.byType(FakeCallScreen));
      expect(state.showIncomingOverlay, isFalse);
    });

    testWidgets('Accepting simulated call transitions to connected in-call screen with timer and End Call', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: FakeCallScreen(),
        ),
      );
      await tester.pump();

      // Trigger call immediately
      await tester.tap(find.text('Ring Phone Immediately'));
      await tester.pump();

      // Tap Accept
      await tester.tap(find.text('Accept'));
      await tester.pump();

      final state = tester.state<FakeCallScreenState>(find.byType(FakeCallScreen));
      expect(state.isCallConnected, isTrue);

      // In-call UI shows controls
      expect(find.text('Mute'), findsOneWidget);
      expect(find.text('Keypad'), findsOneWidget);
      expect(find.text('Speaker'), findsOneWidget);
      expect(find.text('End Call'), findsOneWidget);

      // Tap End Call
      await tester.tap(find.text('End Call'));
      await tester.pump();

      expect(state.showIncomingOverlay, isFalse);
      expect(state.isCallConnected, isFalse);
    });

    testWidgets('App lifecycle: triggers call on resume if scheduled time elapsed while in background', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: FakeCallScreen(),
        ),
      );
      await tester.pump();

      final state = tester.state<FakeCallScreenState>(find.byType(FakeCallScreen));
      state.simulateArmedExpiry();

      // Notify lifecycle state change to resumed
      state.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();

      // Should automatically pop the incoming overlay
      expect(state.showIncomingOverlay, isTrue);

      // Clean up
      state.handleDeclineOrEndCall();
      await tester.pump();
    });

    testWidgets('Incoming call triggered from native intent directly displays incoming overlay with caller name', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: FakeCallScreen(
            initialCallerName: 'Inspector Sharma',
            initialCallerSubtitle: 'Police Station',
            isFromTrigger: true,
            autoAccept: false,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Over the lock screen / incoming call overlay should be visible immediately
      expect(find.text('Inspector Sharma'), findsWidgets);
      expect(find.text('Decline'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);

      final state = tester.state<FakeCallScreenState>(find.byType(FakeCallScreen));
      expect(state.showIncomingOverlay, isTrue);
      expect(state.isCallConnected, isFalse);

      state.handleDeclineOrEndCall();
      await tester.pump();
    });

    testWidgets('Tapping Accept on notification intent launches directly into connected call state', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: FakeCallScreen(
            initialCallerName: 'Mom',
            initialCallerSubtitle: 'Mobile',
            isFromTrigger: true,
            autoAccept: true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final state = tester.state<FakeCallScreenState>(find.byType(FakeCallScreen));
      expect(state.showIncomingOverlay, isTrue);
      expect(state.isCallConnected, isTrue);

      // Connected controls visible
      expect(find.text('Mute'), findsOneWidget);
      expect(find.text('End Call'), findsOneWidget);

      state.handleDeclineOrEndCall();
      await tester.pump();
    });
  });

  group('QuickEscapeScreen Widget Tests', () {
    testWidgets('Renders QuickEscapeScreen with shortcuts to Fake Call, Safety Timer, and Location Sharing', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: QuickEscapeScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('Quick Escape Hub'), findsOneWidget);
      expect(find.text('Simulate Fake Call'), findsOneWidget);
      expect(find.text('Launch Fake Call'), findsOneWidget);
      expect(find.text('Safety Timer'), findsOneWidget);
      expect(find.text('Open Safety Timer'), findsOneWidget);
      expect(find.text('Live Location Sharing'), findsOneWidget);
      expect(find.text('Share Live Location'), findsOneWidget);

      // Distinct SOS section
      expect(find.text('REAL EMERGENCY ONLY'), findsOneWidget);
      expect(find.text('TRIGGER REAL EMERGENCY SOS'), findsOneWidget);
    });

    testWidgets('Tapping Real SOS opens distinct confirmation dialog preventing accidental trigger', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: QuickEscapeScreen(),
        ),
      );
      await tester.pump();

      // Tap SOS button
      await tester.ensureVisible(find.text('TRIGGER REAL EMERGENCY SOS'));
      await tester.tap(find.text('TRIGGER REAL EMERGENCY SOS'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Confirmation dialog must appear
      expect(find.text('Activate Real SOS?'), findsOneWidget);
      expect(find.text('CANCEL'), findsOneWidget);
      expect(find.text('DISPATCH SOS'), findsOneWidget);

      // Tap CANCEL
      await tester.tap(find.text('CANCEL'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Activate Real SOS?'), findsNothing);
    });

    testWidgets('Toggles Decoy disguise view for instant privacy', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: QuickEscapeScreen(),
        ),
      );
      await tester.pump();

      // Scroll to Decoy button and tap
      await tester.ensureVisible(find.text('Open Decoy Disguise Screen (Hide App)'));
      await tester.tap(find.text('Open Decoy Disguise Screen (Hide App)'));
      await tester.pump();

      // Decoy notes app should display
      expect(find.text('Quick Notes'), findsOneWidget);
      expect(find.text('Grocery List'), findsOneWidget);
      expect(find.text('Meeting Agenda'), findsOneWidget);

      // Exit decoy view via lock icon
      await tester.tap(find.byIcon(Icons.lock_open_rounded));
      await tester.pump();

      expect(find.text('Quick Escape Hub'), findsOneWidget);
    });
  });
}
