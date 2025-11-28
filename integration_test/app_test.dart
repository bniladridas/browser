import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:browser/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App launches and shows initial UI', (WidgetTester tester) async {
    // Build the app
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Check for URL input field with hint
    expect(find.text('Enter URL'), findsOneWidget);

    // Check for URL input field
    expect(find.byType(TextField), findsOneWidget);

    // Check for navigation buttons
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });

  testWidgets('URL input', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Enter a URL
    await tester.enterText(find.byType(TextField), 'example.com');
    await tester.pump();

    // Check the text is entered
    expect(find.text('example.com'), findsOneWidget);
  });
}
