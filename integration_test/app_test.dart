// SPDX-License-Identifier: MIT
//
// Copyright 2026 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:browser/main.dart';
import 'package:browser/features/theme_utils.dart';

const testTimeout = Timeout(Duration(seconds: 60));

Future<void> _launchApp(WidgetTester tester,
    {bool enableGitFetch = false}) async {
  await tester
      .pumpWidget(MyApp(aiAvailable: true, enableGitFetch: enableGitFetch));
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final urlFieldFinder = find.byType(TextField).first;

  Future<void> openOverflowMenu(WidgetTester tester) async {
    final menuButton = find.byType(PopupMenuButton<String>);
    expect(menuButton, findsOneWidget);
    await tester.tap(menuButton, warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  Future<void> enableGitFetch(WidgetTester tester) async {
    await openOverflowMenu(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    final gitFetchSwitch = find.byWidgetPredicate(
      (widget) =>
          widget is SwitchListTile &&
          (widget.title as Text).data == 'Enable Git Fetch',
    );
    await tester.tap(gitFetchSwitch);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

  group('Browser App Tests', () {
    testWidgets('App launches and shows initial UI',
        (WidgetTester tester) async {
      // Build the app
      await tester.pumpWidget(const MyApp(aiAvailable: true));
      await Future.delayed(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Check for URL input field
      expect(urlFieldFinder, findsOneWidget);

      // Check for navigation buttons
      expect(find.byIcon(Icons.arrow_back_ios), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_ios), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    }, timeout: testTimeout);

    testWidgets('Bookmark adding and viewing', (WidgetTester tester) async {
      await _launchApp(tester);

      // Enter a URL and load
      const testUrl = 'https://example.com';
      expect(urlFieldFinder, findsOneWidget);
      await tester.enterText(urlFieldFinder, testUrl);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Open menu and add bookmark
      await openOverflowMenu(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Bookmark'), warnIfMissed: false);
      await tester.pumpAndSettle();
      // Dismiss the add bookmark dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Open menu and view bookmarks
      await openOverflowMenu(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bookmarks'), warnIfMissed: false);
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
      await openOverflowMenu(tester);
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
      expect(urlFieldFinder, findsOneWidget);
      await tester.enterText(urlFieldFinder, specialUrl);
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

      // Open settings and toggle private browsing to clear cache
      await openOverflowMenu(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Toggle private browsing (this clears cache)
      final privateSwitch = find.byWidgetPredicate(
        (widget) =>
            widget is SwitchListTile &&
            (widget.title as Text).data == 'Private Browsing',
      );
      await tester.tap(privateSwitch);
      await tester.pumpAndSettle();

      // Save settings
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Should show saved snackbar
      expect(find.text('Settings saved'), findsOneWidget);
    }, timeout: testTimeout);

    testWidgets('Settings dialog and user agent toggle',
        (WidgetTester tester) async {
      await _launchApp(tester);

      // Open menu and go to settings
      await openOverflowMenu(tester);
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
      await _launchApp(tester, enableGitFetch: true);

      // First, enable Git Fetch in settings
      await enableGitFetch(tester);

      // Wait for settings to fully close
      await Future.delayed(const Duration(milliseconds: 500));

      // Now open menu and go to Git Fetch
      await openOverflowMenu(tester);
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
      await openOverflowMenu(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Check for new toggles
      expect(find.text('Private Browsing'), findsOneWidget);
      expect(find.text('Ad Blocking'), findsOneWidget);
      expect(find.byType(DropdownButton<AppThemeMode>), findsOneWidget);

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
      final dropdown = find.byType(DropdownButton<AppThemeMode>);
      await tester.tap(dropdown, warnIfMissed: false);
      await tester.pumpAndSettle();
      // Tap the first DropdownMenuItem with "Theme: dark" (the menu item, not the button label)
      final themeDarkItems = find.ancestor(
        of: find.text('Theme: dark'),
        matching: find.byType(DropdownMenuItem<AppThemeMode>),
      );
      await tester.tap(themeDarkItems.first, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Save settings
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Should show saved snackbar
      expect(find.text('Settings saved'), findsOneWidget);
    }, timeout: testTimeout);
  }, skip: Platform.isLinux || Platform.isWindows);
}
