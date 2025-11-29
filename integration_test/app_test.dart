// SPDX-License-Identifier: MIT
//
// Copyright 2025 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:browser/main.dart';

const testTimeout = Timeout(Duration(seconds: 60));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Browser App Tests', () {
    testWidgets('App launches and shows initial UI', (WidgetTester tester) async {
      // Build the app
      await tester.pumpWidget(const MyApp());
      await Future.delayed(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Check for URL input field with hint
      expect(find.text('Enter URL'), findsOneWidget);

      // Check for URL input field
      expect(find.byType(TextField), findsOneWidget);

      // Check for navigation buttons
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);

      // Check for bookmarks buttons
      expect(find.byIcon(Icons.bookmark_add), findsOneWidget);
      expect(find.byIcon(Icons.bookmarks), findsOneWidget);
    }, timeout: testTimeout);

    testWidgets('URL input and https prepend', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Enter a URL without https
      await tester.enterText(find.byType(TextField), 'example.com');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle(); // Allow time for webview callback and state update

       // Verify that the TextField's controller has the updated text with https:// prepended
       final textField = tester.widget<TextField>(find.byType(TextField));
       expect(textField.controller!.text, startsWith('https://example.com'));
    }, timeout: testTimeout);

    testWidgets('Search query prepend', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Enter a search query
      await tester.enterText(find.byType(TextField), 'flutter development');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

       // Verify that the TextField's controller has the search URL
       final textField = tester.widget<TextField>(find.byType(TextField));
       expect(textField.controller!.text, 'https://www.google.com/search?q=flutter%20development');
    }, timeout: testTimeout);



    testWidgets('Bookmark adding and viewing', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Add a bookmark
      await tester.tap(find.byIcon(Icons.bookmark_add));
      await tester.pumpAndSettle();

      // View bookmarks
      await tester.tap(find.byIcon(Icons.bookmarks));
      await tester.pumpAndSettle();

      // Should show bookmarks dialog
      expect(find.text('Bookmarks'), findsOneWidget);
      expect(find.byType(ListTile), findsAtLeast(1)); // At least one bookmark
    }, timeout: testTimeout);

    testWidgets('History viewing', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // View history
      await tester.tap(find.byIcon(Icons.history));
      await tester.pumpAndSettle();

      // Should show history dialog
      expect(find.text('History'), findsOneWidget);
    }, timeout: testTimeout);

    testWidgets('Invalid URL handling', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Enter an invalid URL (treated as search query)
      await tester.enterText(find.byType(TextField), 'invalid url query');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Should convert to search URL
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller!.text, 'https://www.google.com/search?q=invalid%20url%20query');
    }, timeout: testTimeout);

  });
}
