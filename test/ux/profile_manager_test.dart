// SPDX-License-Identifier: MIT
//
// Copyright 2026 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'package:browser/constants.dart';
import 'package:browser/features/profile_manager.dart';
import 'package:browser/features/theme_utils.dart';
import 'package:browser/main.dart';
import 'package:browser/models/user_profile.dart';
import 'package:browser/ux/browser_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProfileManager', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      profileManager.resetForTesting();
      await profileManager.initialize();
    });

    test('creates default profile on first initialize', () {
      expect(profileManager.profiles.length, 1);
      expect(profileManager.profiles.first.id, 'default');
      expect(profileManager.profiles.first.name, 'Default');
      expect(profileManager.activeProfileId, 'default');
    });

    test('creates new profile with custom name', () async {
      final profile = await profileManager.createProfile('Work');

      expect(profileManager.profiles.length, 2);
      expect(profile.name, 'Work');
      expect(profileManager.profiles.last.name, 'Work');
    });

    test('creates new profile with selected color', () async {
      final profile = await profileManager.createProfile('Personal',
          colorValue: 0xFFEA4335);

      expect(profile.colorValue, 0xFFEA4335);
    });

    test('switchProfile changes active profile', () async {
      final workProfile = await profileManager.createProfile('Work');
      await profileManager.switchProfile(workProfile.id);

      expect(profileManager.activeProfileId, workProfile.id);
      expect(profileManager.activeProfile?.name, 'Work');
    });

    test('switchProfile does nothing for same profile', () async {
      final activeBefore = profileManager.activeProfileId;
      await profileManager.switchProfile(activeBefore!);

      expect(profileManager.activeProfileId, activeBefore);
    });

    test('deleteProfile removes profile', () async {
      final workProfile = await profileManager.createProfile('WorkDelete');
      final countBefore = profileManager.profiles.length;

      await profileManager.deleteProfile(workProfile.id);

      expect(profileManager.profiles.length, countBefore - 1);
      expect(
          profileManager.profiles.any((p) => p.name == 'WorkDelete'), isFalse);
    });

    test('deleteProfile cannot delete default profile', () {
      expect(profileManager.canDelete('default'), isFalse);
      expect(profileManager.canDelete('fake_id'), isTrue);
    });

    test('deleteProfile switches to default if deleting active', () async {
      final workProfile = await profileManager.createProfile('Work');
      await profileManager.switchProfile(workProfile.id);

      await profileManager.deleteProfile(workProfile.id);

      expect(profileManager.activeProfileId, 'default');
    });

    test('profile storage keys are scoped by active profile', () {
      expect(profileManager.bookmarksKey, 'default_$bookmarksStorageKey');
      expect(profileManager.historyKey, 'default_$browsingHistoryKey');
    });

    test('profile storage keys change with active profile', () async {
      final workProfile = await profileManager.createProfile('Work');
      await profileManager.switchProfile(workProfile.id);

      expect(profileManager.bookmarksKey,
          '${workProfile.id}_$bookmarksStorageKey');
      expect(
          profileManager.historyKey, '${workProfile.id}_$browsingHistoryKey');
    });

    test('notifies listeners on profile creation and switch', () async {
      int notifyCount = 0;
      profileManager.addListener(() => notifyCount++);

      final workProfile = await profileManager.createProfile('Work');
      expect(notifyCount, 1);

      await profileManager.switchProfile(workProfile.id);
      expect(notifyCount, 2);
    });

    test('persists active profile', () async {
      final newPm = ProfileManager();
      SharedPreferences.setMockInitialValues({
        'user_profiles':
            '[{"id":"profile_test","name":"Test","colorValue":4285,"createdAt":"2024-01-01T00:00:00.000","isActive":false}]',
        'active_profile_id': 'profile_test',
      });
      await newPm.initialize();

      expect(newPm.activeProfileId, 'profile_test');
      expect(newPm.profiles.length, 1);
    });

    test('migrates legacy prefs into default profile', () async {
      SharedPreferences.setMockInitialValues({
        tabFaviconBadgeEnabledKey: true,
        autoHideAddressBarKey: true,
        bookmarksStorageKey: '{"v":1,"items":[]}',
        browsingHistoryKey: '[]',
      });
      profileManager.resetForTesting();
      await profileManager.initialize();

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool(
            profileManager.getScopedStorageKey(tabFaviconBadgeEnabledKey)),
        isTrue,
      );
      expect(
        prefs
            .getBool(profileManager.getScopedStorageKey(autoHideAddressBarKey)),
        isTrue,
      );
      expect(
        prefs
            .getString(profileManager.getScopedStorageKey(bookmarksStorageKey)),
        '{"v":1,"items":[]}',
      );
      expect(
        prefs.getString(profileManager.getScopedStorageKey(browsingHistoryKey)),
        '[]',
      );

      expect(prefs.getBool(tabFaviconBadgeEnabledKey), isNull);
      expect(prefs.getBool(autoHideAddressBarKey), isNull);
      expect(prefs.getString(bookmarksStorageKey), isNull);
      expect(prefs.getString(browsingHistoryKey), isNull);
    });
  });

  group('UserProfile model', () {
    test('creates profile from JSON', () {
      final json = {
        'id': 'test_id',
        'name': 'Test Profile',
        'colorValue': 0xFF4285F4,
        'createdAt': '2024-01-01T00:00:00.000',
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.id, 'test_id');
      expect(profile.name, 'Test Profile');
      expect(profile.colorValue, 0xFF4285F4);
    });

    test('converts profile to JSON', () {
      final profile = UserProfile(
        id: 'test_id',
        name: 'Test Profile',
        colorValue: 0xFF4285F4,
        createdAt: DateTime(2024, 1, 1),
      );

      final json = profile.toJson();

      expect(json['id'], 'test_id');
      expect(json['name'], 'Test Profile');
      expect(json['colorValue'], 0xFF4285F4);
      expect(json.containsKey('isActive'), isFalse);
    });

    test('available colors list is not empty', () {
      expect(UserProfile.availableColors, isNotEmpty);
      expect(UserProfile.availableColors.length, greaterThanOrEqualTo(8));
    });

    test('profile equality based on id', () {
      final profile1 = UserProfile(
        id: 'same_id',
        name: 'Profile 1',
        colorValue: 0xFF4285F4,
        createdAt: DateTime.now(),
      );

      final profile2 = UserProfile(
        id: 'same_id',
        name: 'Profile 2',
        colorValue: 0xFFEA4335,
        createdAt: DateTime.now(),
      );

      expect(profile1, equals(profile2));
    });
  });

  group('Profile Manager Dialog UI', () {
    testWidgets('displays profile section in Settings', (tester) async {
      SharedPreferences.setMockInitialValues({});
      profileManager.resetForTesting();
      await profileManager.initialize();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (_) => SettingsDialog(
                        aiAvailable: false,
                        currentTheme: AppThemeMode.system,
                      ),
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Profile'), findsWidgets);
    });
  });
}
