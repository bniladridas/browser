// SPDX-License-Identifier: MIT
//
// Copyright 2026 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'package:browser/constants.dart';
import 'package:browser/features/theme_utils.dart';
import 'package:browser/ux/browser_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Finder _switchTileByTitle(String title) {
  return find.ancestor(
    of: find.text(title),
    matching: find.byType(SwitchListTile),
  );
}

SwitchListTile _readSwitchTile(WidgetTester tester, String title) {
  final finder = _switchTileByTitle(title);
  expect(finder, findsOneWidget);
  return tester.widget<SwitchListTile>(finder);
}

Widget _dialogHost({
  required bool aiAvailable,
  void Function()? onSettingsChanged,
  void Function(AppThemeMode mode)? onThemePreviewChanged,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) {
          return Center(
            child: TextButton(
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (_) => SettingsDialog(
                    aiAvailable: aiAvailable,
                    currentTheme: AppThemeMode.system,
                    onSettingsChanged: onSettingsChanged,
                    onThemePreviewChanged: onThemePreviewChanged,
                  ),
                );
              },
              child: const Text('Open Settings'),
            ),
          );
        },
      ),
    ),
  );
}

Future<void> _openSettingsDialog(WidgetTester tester, Widget host) async {
  await tester.pumpWidget(host);
  await tester.tap(find.text('Open Settings'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsDialog', () {
    testWidgets('loads persisted switch and theme values',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        useModernUserAgentKey: true,
        enableGitFetchKey: true,
        aiSearchSuggestionsEnabledKey: true,
        themeModeKey: AppThemeMode.dark.name,
      });

      await _openSettingsDialog(
        tester,
        _dialogHost(aiAvailable: false),
      );

      expect(_readSwitchTile(tester, 'Legacy User Agent').value, isTrue);
      expect(_readSwitchTile(tester, 'Git Fetch').value, isTrue);
      expect(_readSwitchTile(tester, 'AI Search Suggestions').value, isTrue);

      final darkChip = find.widgetWithText(ChoiceChip, 'dark');
      expect(darkChip, findsOneWidget);
      expect(tester.widget<ChoiceChip>(darkChip).selected, isTrue);
    });

    testWidgets('save persists toggles and theme preview callback',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        useModernUserAgentKey: false,
        aiSearchSuggestionsEnabledKey: false,
        themeModeKey: AppThemeMode.system.name,
      });

      final previewModes = <AppThemeMode>[];

      await _openSettingsDialog(
        tester,
        _dialogHost(
          aiAvailable: false,
          onThemePreviewChanged: previewModes.add,
        ),
      );

      final settingsScrollable = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(Scrollable),
      );

      await tester.tap(_switchTileByTitle('Legacy User Agent'));
      await tester.pumpAndSettle();

      if (settingsScrollable.evaluate().isNotEmpty) {
        await tester.scrollUntilVisible(
          _switchTileByTitle('AI Search Suggestions'),
          120,
          scrollable: settingsScrollable.first,
        );
      }
      await tester.tap(_switchTileByTitle('AI Search Suggestions'));
      await tester.pumpAndSettle();

      final darkChip = find.widgetWithText(ChoiceChip, 'dark');
      if (settingsScrollable.evaluate().isNotEmpty) {
        await tester.scrollUntilVisible(
          darkChip,
          120,
          scrollable: settingsScrollable.first,
        );
      }
      await tester.tap(darkChip, warnIfMissed: false);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(useModernUserAgentKey), isTrue);
      expect(prefs.getBool(aiSearchSuggestionsEnabledKey), isTrue);
      expect(prefs.getString(themeModeKey), AppThemeMode.dark.name);
      expect(previewModes, contains(AppThemeMode.dark));
    });

    testWidgets('cancel does not persist modified values',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        useModernUserAgentKey: false,
      });

      var settingsChangedCount = 0;
      await _openSettingsDialog(
        tester,
        _dialogHost(
          aiAvailable: false,
          onSettingsChanged: () => settingsChangedCount++,
        ),
      );

      await tester.tap(_switchTileByTitle('Legacy User Agent'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(useModernUserAgentKey), isFalse);
      expect(settingsChangedCount, 0);
    });

    testWidgets('displays Firebase configuration fields',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      await _openSettingsDialog(
        tester,
        _dialogHost(aiAvailable: false),
      );

      // Scroll to Firebase section
      final settingsScrollable = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('Config'),
        100,
        scrollable: settingsScrollable.first,
      );

      expect(find.text('Config'), findsOneWidget);

      // Expand Firebase config
      await tester.tap(find.text('Config'));
      await tester.pumpAndSettle();

      expect(find.text('API Key'), findsOneWidget);
      expect(find.text('App ID'), findsOneWidget);
      expect(find.text('Sender ID'), findsOneWidget);
      expect(find.text('Project ID'), findsOneWidget);
      expect(find.text('Storage'), findsOneWidget);
    });

    testWidgets('loads Firebase keys for settings fields',
        (WidgetTester tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({
        firebaseApiKeyPref: 'test-api-key',
        firebaseAppIdPref: 'test-app-id',
        firebaseProjectIdPref: 'test-project',
      });

      await _openSettingsDialog(
        tester,
        _dialogHost(aiAvailable: false),
      );

      // Scroll to Firebase section
      final settingsScrollable = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('Config'),
        100,
        scrollable: settingsScrollable.first,
      );

      // Expand Firebase config
      await tester.tap(find.text('Config'));
      await tester.pumpAndSettle();

      // Scroll to fields
      await tester.scrollUntilVisible(
        find.text('API Key'),
        100,
        scrollable: settingsScrollable.first,
      );

      final apiKeyField = tester.widget<TextField>(
        find.ancestor(
          of: find.text('API Key'),
          matching: find.byType(TextField),
        ),
      );
      final appIdField = tester.widget<TextField>(
        find.ancestor(
          of: find.text('App ID'),
          matching: find.byType(TextField),
        ),
      );
      final projectIdField = tester.widget<TextField>(
        find.ancestor(
          of: find.text('Project ID'),
          matching: find.byType(TextField),
        ),
      );

      expect(apiKeyField.controller?.text, 'test-api-key');
      expect(appIdField.controller?.text, 'test-app-id');
      expect(projectIdField.controller?.text, 'test-project');
    });

    testWidgets('saves Firebase keys to secure storage',
        (WidgetTester tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});

      await _openSettingsDialog(
        tester,
        _dialogHost(aiAvailable: false),
      );

      // Scroll to Firebase section
      final settingsScrollable = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('Config'),
        100,
        scrollable: settingsScrollable.first,
      );

      // Expand Firebase config
      await tester.tap(find.text('Config'));
      await tester.pumpAndSettle();

      // Scroll to fields
      await tester.scrollUntilVisible(
        find.text('API Key'),
        100,
        scrollable: settingsScrollable.first,
      );

      final apiKeyField = find.ancestor(
        of: find.text('API Key'),
        matching: find.byType(TextField),
      );
      final appIdField = find.ancestor(
        of: find.text('App ID'),
        matching: find.byType(TextField),
      );

      await tester.enterText(apiKeyField, 'new-api-key');
      await tester.pumpAndSettle();
      await tester.enterText(appIdField, 'new-app-id');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      const secureStorage = FlutterSecureStorage();
      final storedApiKey = await secureStorage.read(key: firebaseApiKeyPref);
      final storedAppId = await secureStorage.read(key: firebaseAppIdPref);
      final prefs = await SharedPreferences.getInstance();
      expect(storedApiKey, 'new-api-key');
      expect(storedAppId, 'new-app-id');
      expect(prefs.getString(firebaseApiKeyPref), isNull);
      expect(prefs.getString(firebaseAppIdPref), isNull);
    });
  });
}
