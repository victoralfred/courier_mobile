import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delivery_app/app.dart';
import 'package:delivery_app/core/config/app_config.dart';
import 'package:delivery_app/core/config/environment.dart';

void main() {
  testWidgets('CourierApp displays correctly', (WidgetTester tester) async {
    // Set up the environment for testing
    AppConfig.setEnvironment(Environment.development);

    // Build our app and trigger a frame.
    await tester.pumpWidget(const CourierApp());

    // Verify that the app title is displayed
    expect(find.text('Courier Delivery'), findsOneWidget);

    // Verify the shipping icon is displayed
    expect(find.byIcon(Icons.local_shipping), findsOneWidget);

    // Verify environment text is displayed
    expect(find.text('Environment: Development'), findsOneWidget);
  });
}
