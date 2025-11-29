// SPDX-License-Identifier: MIT
//
// Copyright 2025 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:browser/main.dart';

const testTimeout = Timeout(Duration(seconds: 120));

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

      // Check for menu button containing bookmarks and history
      expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    }, timeout: testTimeout);

    testWidgets('Bookmark adding and viewing', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Enter a URL and load
      const testUrl = 'https://example.com';
      await tester.enterText(find.byType(TextField), testUrl);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Open menu and add bookmark
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Bookmark'));
      await tester.pumpAndSettle();

      // Open menu and view bookmarks
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bookmarks'));
      await tester.pumpAndSettle();

      // Should show bookmarks dialog
      expect(find.text('Bookmarks'), findsOneWidget);
    }, timeout: testTimeout);

    testWidgets('History viewing', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Open menu and view history
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();

      // Should show history dialog
      expect(find.text('History'), findsOneWidget);
    }, timeout: testTimeout);



    testWidgets('Special characters in URL', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Enter URL with special characters
      const specialUrl = 'https://example.com/path?query=value&other=test';
      await tester.enterText(find.byType(TextField), specialUrl);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Should handle special characters
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller!.text, specialUrl);
    }, timeout: testTimeout);
  });
}