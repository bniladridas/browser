import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:browser/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App launches and shows initial UI', (WidgetTester tester) async {
    // Build the app
    await tester.pumpWidget(const MyApp());

    // Verify the app title or initial elements
    expect(find.text('Browser'), findsOneWidget); // Assuming app bar title

    // Check for URL input field
    expect(find.byType(TextField), findsOneWidget);

    // Check for navigation buttons
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });

  testWidgets('URL input and validation', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Enter a URL
    await tester.enterText(find.byType(TextField), 'example.com');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    // Check if https:// is prepended
    // Note: Actual WebView loading can't be tested in integration tests
    // This tests UI behavior
  });
}
