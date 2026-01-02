// SPDX-License-Identifier: MIT
//
// Copyright 2025 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:browser/main.dart';

const testTimeout = Timeout(Duration(seconds: 60));

Future<void> _launchApp(WidgetTester tester) async {
  await tester.pumpWidget(const MyApp());
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  if (Platform.isMacOS) {
    return;
  }

  group('Browser App Tests', () {
    testWidgets('App launches and shows initial UI',
        (WidgetTester tester) async {
      // Build the app
      await tester.pumpWidget(const MyApp());
      await Future.delayed(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Check for URL input field
      expect(find.byType(TextField), findsOneWidget);

      // Check for navigation buttons
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    }, timeout: testTimeout);

    testWidgets('Bookmark adding and viewing', (WidgetTester tester) async {
      await _launchApp(tester);

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
      expect(
          find.descendant(
              of: find.byType(AlertDialog), matching: find.text('Bookmarks')),
          findsOneWidget);
    }, timeout: testTimeout);

    testWidgets('History viewing', (WidgetTester tester) async {
      await _launchApp(tester);

      // Open menu and view history
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();

      // Should show history dialog
      expect(find.text('History'), findsOneWidget);
    }, timeout: testTimeout);

    testWidgets('Special characters in URL', (WidgetTester tester) async {
      await _launchApp(tester);

      // Enter URL with special characters
      const specialUrl = 'https://github.com/bniladridas/browser?tab=readme';
      await tester.enterText(find.byType(TextField), specialUrl);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Should handle special characters (skip on desktop where webview fails)
      if (Platform.isAndroid || Platform.isIOS) {
        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller!.text, specialUrl);
      }
    }, timeout: testTimeout);

    testWidgets('Clear cache functionality', (WidgetTester tester) async {
      await _launchApp(tester);

      // Open menu and clear cache
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear Cache'));
      await tester.pumpAndSettle();

      // Should show cache cleared snackbar
      expect(find.text('Cache cleared'), findsOneWidget);
    }, timeout: testTimeout);

    testWidgets('Settings dialog and user agent toggle',
        (WidgetTester tester) async {
      await _launchApp(tester);

      // Open menu and go to settings
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Should show settings dialog
      expect(find.text('Settings'), findsOneWidget);

      // Check for user agent switch
      expect(find.text('Use Modern User Agent'), findsOneWidget);

      // Toggle the switch
      final switchFinder = find.byType(SwitchListTile).first;
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Save settings
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Should show saved snackbar
      expect(find.text('Settings saved'), findsOneWidget);
    }, timeout: testTimeout);

    testWidgets('Git fetch dialog', (WidgetTester tester) async {
      await _launchApp(tester);

      // First, enable Git Fetch in settings
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Enable Git Fetch toggle
      final gitFetchSwitch = find.byWidgetPredicate(
        (widget) =>
            widget is SwitchListTile &&
            (widget.title as Text).data == 'Enable Git Fetch',
      );
      await tester.tap(gitFetchSwitch);
      await tester.pumpAndSettle();

      // Save settings
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Close settings
      await tester
          .tap(find.text('Settings saved')); // Wait for snackbar or just pump
      await tester.pumpAndSettle();

      // Now open menu and go to Git Fetch
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Git Fetch'));
      await tester.pumpAndSettle();

      // Should show Git Fetch dialog
      expect(find.text('Git Fetch'), findsOneWidget);

      // Enter a repo
      const testRepo = 'flutter/flutter';
      await tester.enterText(
          find.bySemanticsLabel('GitHub Repo (owner/repo)'), testRepo);
      await tester.pumpAndSettle();

      // Tap Fetch
      await tester.tap(find.text('Fetch'));
      await tester.pumpAndSettle();

      // Should show loading or results (skip detailed check due to network)
      // For now, just ensure dialog stays open
      expect(find.text('Git Fetch'), findsOneWidget);
    }, timeout: testTimeout);

    testWidgets('New feature toggles in settings', (WidgetTester tester) async {
      await _launchApp(tester);

      // Open settings
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Check for new toggles
      expect(find.text('Private Browsing'), findsOneWidget);
      expect(find.text('Ad Blocking'), findsOneWidget);
      expect(find.text('Theme:'), findsOneWidget); // Dropdown

      // Toggle private browsing
      final privateSwitch = find.byWidgetPredicate(
        (widget) =>
            widget is SwitchListTile &&
            (widget.title as Text).data == 'Private Browsing',
      );
      await tester.tap(privateSwitch);
      await tester.pumpAndSettle();

      // Toggle ad blocking
      final adSwitch = find.byWidgetPredicate(
        (widget) =>
            widget is SwitchListTile &&
            (widget.title as Text).data == 'Ad Blocking',
      );
      await tester.tap(adSwitch);
      await tester.pumpAndSettle();

      // Change theme to dark
      final dropdown = find.byType(DropdownButton);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Theme: dark'));
      await tester.pumpAndSettle();

      // Save settings
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Should show saved snackbar
      expect(find.text('Settings saved'), findsOneWidget);
    }, timeout: testTimeout);
  });
}
