import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_demo_application/main.dart';

void main() {
  testWidgets('Weather app starts and shows loading spinner', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const WeatherApp());

    // Verify that the loading spinner is shown.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
