import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nirbhay/main.dart';

void main() {
  testWidgets('Nirbhay App smoke test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Build the Nirbhay app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify MaterialApp mounts
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
