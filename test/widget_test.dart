import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nirbhay/main.dart';

void main() {
  testWidgets('Dashboard smoke test', (WidgetTester tester) async {
    // Set a large screen size to prevent fallback font overflows in rows
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that our dashboard screen loads and displays the meeting workspace header.
    expect(find.text('Meeting Workspace'), findsOneWidget);
    expect(find.text('Extracted Actions'), findsOneWidget);
  });
}
