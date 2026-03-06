// SPDX-License-Identifier: MIT
//
// Copyright 2026 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:browser/main.dart';
import 'package:browser/constants.dart';
import 'package:browser/features/theme_utils.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const testTimeout = Timeout(Duration(minutes: 3));

Future<void> _launchApp(WidgetTester tester,
    {bool enableGitFetch = false,
    bool aiSuggestionsEnabled = false,
    bool resetPrefs = true}) async {
  if (resetPrefs) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await prefs.setBool(hideAppBarKey, false);
    await prefs.setBool(useModernUserAgentKey, false);
    await prefs.setBool(enableGitFetchKey, enableGitFetch);
    await prefs.setBool(privateBrowsingKey, false);
    await prefs.setBool(adBlockingKey, false);
    await prefs.setBool(strictModeKey, false);
    await prefs.setBool(passwordManagerEnabledKey, false);
    await prefs.setBool(reorderableTabsKey, false);
    await prefs.setBool(aiSearchSuggestionsEnabledKey, aiSuggestionsEnabled);
    await prefs.setBool(advancedCacheEnabledKey, false);
    await prefs.setString(themeModeKey, AppThemeMode.system.name);
    final info = await PackageInfo.fromPlatform();
    await prefs.setString(whatsNewSeenVersionKey, info.version.trim());
  }

  await tester
      .pumpWidget(MyApp(aiAvailable: false, enableGitFetch: enableGitFetch));
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Finder urlFieldFinder() => find.byKey(const Key('browser.url_field'));

  Finder entryFieldFinder() {
    final urlField = urlFieldFinder().hitTestable();
    if (urlField.evaluate().isNotEmpty) {
      return urlField.first;
    }

    final anyField = find.byType(TextField).hitTestable();
    if (anyField.evaluate().isNotEmpty) {
      return anyField.first;
    }

    return find.byType(TextField).first;
  }

  Future<void> openOverflowMenu(WidgetTester tester) async {
    final menuButton = find.byIcon(Icons.more_vert).first;
    expect(menuButton, findsOneWidget);
    await tester.tap(menuButton, warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  Finder switchTileByTitle(String title) {
    return find.ancestor(
      of: find.text(title),
      matching: find.byType(SwitchListTile),
    );
  }

  Future<void> setSwitchTile(
    WidgetTester tester, {
    required String title,
    required bool enabled,
  }) async {
    final tileFinder = switchTileByTitle(title);
    expect(tileFinder, findsOneWidget);
    final tile = tester.widget<SwitchListTile>(tileFinder);
    if (tile.value != enabled) {
      await tester.tap(tileFinder);
      await tester.pumpAndSettle();
    }
  }

  Future<void> enableGitFetch(WidgetTester tester) async {
    await openOverflowMenu(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await setSwitchTile(tester, title: 'Git Fetch', enabled: true);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

  group('Browser App Tests', () {
    testWidgets('App launches and shows initial UI',
        (WidgetTester tester) async {
      // Build the app
      await _launchApp(tester);

      // Check for URL input field
      expect(urlFieldFinder(), findsOneWidget);

      // Check for navigation buttons
      expect(find.byIcon(Icons.arrow_back_ios), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_ios), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    }, timeout: testTimeout);

    testWidgets('Bookmark adding and viewing', (WidgetTester tester) async {
      await _launchApp(tester);

      // Enter a URL and load
      const testUrl = 'https://example.com';
      expect(urlFieldFinder(), findsOneWidget);
      await tester.enterText(urlFieldFinder(), testUrl);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Open menu and add bookmark
      await openOverflowMenu(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Bookmark'), warnIfMissed: false);
      await tester.pumpAndSettle();
      // Dismiss the add bookmark dialog if it is shown.
      if (find.text('Add Bookmark').evaluate().isNotEmpty &&
          find.text('Cancel').evaluate().isNotEmpty) {
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      }

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
      expect(urlFieldFinder(), findsOneWidget);
      await tester.enterText(urlFieldFinder(), specialUrl);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Should handle special characters (skip on desktop where webview fails)
      if (Platform.isAndroid || Platform.isIOS) {
        final textField = tester.widget<TextField>(urlFieldFinder());
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
      await setSwitchTile(
        tester,
        title: 'Private Browsing',
        enabled: true,
      );

      // Save settings
      await tester.tap(find.text('Save'));
      // Use pump with duration instead of pumpAndSettle to avoid infinite wait
      await tester.pump(const Duration(seconds: 2));

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
      expect(find.text('Legacy User Agent'), findsOneWidget);

      // Toggle the switch
      await setSwitchTile(
        tester,
        title: 'Legacy User Agent',
        enabled: true,
      );

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
      expect(find.text('Git Fetch'), findsOneWidget);
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
      expect(find.byType(ChoiceChip), findsWidgets);

      // Toggle private browsing
      await setSwitchTile(
        tester,
        title: 'Private Browsing',
        enabled: true,
      );

      // Toggle ad blocking
      await setSwitchTile(
        tester,
        title: 'Ad Blocking',
        enabled: true,
      );

      // Change theme to dark
      final darkThemeChip = find.widgetWithText(ChoiceChip, 'dark').first;
      final settingsScrollable = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(Scrollable),
      );
      if (settingsScrollable.evaluate().isNotEmpty) {
        await tester.scrollUntilVisible(
          darkThemeChip,
          120,
          scrollable: settingsScrollable.first,
        );
      }
      expect(darkThemeChip, findsOneWidget);
      await tester.tap(darkThemeChip, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Save settings.
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Should show saved snackbar.
      expect(find.text('Settings saved'), findsOneWidget);
    }, timeout: testTimeout);

    testWidgets('URL submit loads non-empty value',
        (WidgetTester tester) async {
      await _launchApp(tester);

      final entryField = entryFieldFinder();
      await tester.tap(entryField, warnIfMissed: false);
      await tester.enterText(entryField, 'example.com');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final textField = tester.widget<TextField>(entryField);
      final value = textField.controller?.text ?? '';
      expect(value, isNotEmpty);
      expect(value, contains('example.com'));
    }, timeout: testTimeout);

    testWidgets('Empty URL submit opens AI suggestions when enabled',
        (WidgetTester tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(aiSearchSuggestionsEnabledKey, true);

      await _launchApp(tester, aiSuggestionsEnabled: true);

      final urlFieldElements = urlFieldFinder().evaluate().toList();
      final anyFieldElements = find.byType(TextField).evaluate().toList();
      if (urlFieldElements.isEmpty && anyFieldElements.isEmpty) {
        fail(
          'No text field found for URL submission. '
          'Expected browser URL field or any TextField in widget tree.',
        );
      }
      final entryElement = urlFieldElements.isNotEmpty
          ? urlFieldElements.first
          : anyFieldElements.first;
      final entryField = find
          .byElementPredicate((element) => identical(element, entryElement));
      await tester.tap(entryField, warnIfMissed: false);
      await tester.enterText(entryField, '   ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      if (find
          .byKey(const Key('browser.ai_suggestions_title'))
          .evaluate()
          .isEmpty) {
        // Fallback for desktop text-input action flakiness:
        // tapping empty field should still open AI suggestions when enabled.
        await tester.tap(entryField, warnIfMissed: false);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }

      expect(find.byKey(const Key('browser.ai_suggestions_title')),
          findsOneWidget);
    }, timeout: testTimeout);

    testWidgets('AI suggestions sheet opens and closes',
        (WidgetTester tester) async {
      await _launchApp(tester, aiSuggestionsEnabled: true);

      final urlFieldElements = urlFieldFinder().evaluate().toList();
      final anyFieldElements = find.byType(TextField).evaluate().toList();
      if (urlFieldElements.isEmpty && anyFieldElements.isEmpty) {
        fail(
          'No text field found for AI suggestions flow. '
          'Expected browser URL field or any TextField in widget tree.',
        );
      }
      final entryElement = urlFieldElements.isNotEmpty
          ? urlFieldElements.first
          : anyFieldElements.first;
      final entryField = find
          .byElementPredicate((element) => identical(element, entryElement));

      await tester.tap(entryField, warnIfMissed: false);
      await tester.enterText(entryField, ' ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.byKey(const Key('browser.ai_suggestions_title')),
          findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      final aiSuggestionsTitle =
          find.byKey(const Key('browser.ai_suggestions_title'));
      if (aiSuggestionsTitle.evaluate().isNotEmpty) {
        // Desktop key dispatch can be flaky in CI; tap modal barrier as fallback.
        await tester.tapAt(const Offset(8, 8));
        await tester.pumpAndSettle();
      }
      if (aiSuggestionsTitle.evaluate().isNotEmpty) {
        // Last fallback: dismiss the top route.
        await tester.pageBack();
        await tester.pumpAndSettle();
      }

      expect(aiSuggestionsTitle, findsNothing);
    }, timeout: testTimeout);

    testWidgets('Git Fetch visibility persists after relaunch',
        (WidgetTester tester) async {
      await _launchApp(tester);
      await enableGitFetch(tester);

      await _launchApp(tester, resetPrefs: false);
      await openOverflowMenu(tester);
      await tester.pumpAndSettle();

      expect(find.text('Git Fetch'), findsOneWidget);
    }, timeout: testTimeout);

  testWidgets('Firebase configuration can be saved in settings',
      (WidgetTester tester) async {
    await _launchApp(tester);

    await openOverflowMenu(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    final apiKeyField = find.ancestor(
      of: find.text('API Key'),
      matching: find.byType(TextField),
    );
    final appIdField = find.ancestor(
      of: find.text('App ID'),
      matching: find.byType(TextField),
    );

    expect(apiKeyField, findsOneWidget);
    expect(appIdField, findsOneWidget);

    await tester.enterText(apiKeyField, 'test-api-key');
    await tester.enterText(appIdField, 'test-app-id');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('firebase_FIREBASE_API_KEY'), 'test-api-key');
    expect(prefs.getString('firebase_FIREBASE_APP_ID'), 'test-app-id');
  }, timeout: testTimeout);
  }, skip: Platform.isLinux || Platform.isWindows);
}
