// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:browser/main.dart';

void main() {
  testWidgets('App loads with browser interface', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the browser interface elements are present
    expect(find.text('Enter URL'), findsOneWidget);
    expect(find.text('Enter a URL in the bar above and press Enter to open it in your default browser.'), findsOneWidget);
  });
}
