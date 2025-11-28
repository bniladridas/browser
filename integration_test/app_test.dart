// SPDX-License-Identifier: MIT
//
// Copyright 2025 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:browser/main.dart';

const testTimeout = Timeout(Duration(seconds: 30));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Browser App Tests', () {
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
  });
}
