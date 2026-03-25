// SPDX-License-Identifier: MIT
//
// Copyright 2026 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';
import '../constants.dart';

class ProfileManager extends ChangeNotifier {
  static const String _profilesKey = 'user_profiles';
  static const String _activeProfileIdKey = 'active_profile_id';
  static const String _defaultProfileId = 'default';
  static const String _legacySettingsMigratedKey =
      'profile_settings_legacy_migrated_v1';

  SharedPreferences? _prefs;
  List<UserProfile> _profiles = [];
  String? _activeProfileId;

  List<UserProfile> get profiles => List.unmodifiable(_profiles);
  String? get activeProfileId => _activeProfileId;
  UserProfile? get activeProfile =>
      _profiles.where((p) => p.id == _activeProfileId).firstOrNull;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadProfiles();
    await _ensureDefaultProfile();
    await _migrateLegacySettingsToDefaultProfile();
  }

  Future<void> _loadProfiles() async {
    final profilesJson = _prefs?.getString(_profilesKey);
    if (profilesJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(profilesJson);
        _profiles = decoded
            .map((e) => UserProfile.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        _profiles = [];
        if (_prefs != null) {
          await _prefs!.remove(_profilesKey);
        }
      }
    }
    _activeProfileId = _prefs?.getString(_activeProfileIdKey);
  }

  Future<void> _saveProfiles() async {
    if (_prefs == null) {
      throw StateError(
          'ProfileManager._saveProfiles: _prefs is null. Call initialize() first.');
    }
    final json = jsonEncode(_profiles.map((p) => p.toJson()).toList());
    await _prefs!.setString(_profilesKey, json);
  }

  Future<void> _setActiveProfileId(String id) async {
    if (_prefs == null) {
      throw StateError(
          'ProfileManager._setActiveProfileId: _prefs is null. Call initialize() first.');
    }
    _activeProfileId = id;
    await _prefs!.setString(_activeProfileIdKey, id);
    await _prefs!.reload();
  }

  Future<void> _ensureDefaultProfile() async {
    if (_profiles.isEmpty) {
      final defaultProfile = UserProfile(
        id: _defaultProfileId,
        name: 'Default',
        colorValue: UserProfile.availableColors[0],
        createdAt: DateTime.now(),
      );
      _profiles.add(defaultProfile);
      await _setActiveProfileId(defaultProfile.id);
      await _saveProfiles();
    } else if (_activeProfileId == null ||
        !_profiles.any((p) => p.id == _activeProfileId)) {
      await _setActiveProfileId(_profiles.first.id);
    }
  }

  Future<void> _migrateLegacySettingsToDefaultProfile() async {
    final prefs = _prefs;
    if (prefs == null) return;
    if (prefs.getBool(_legacySettingsMigratedKey) == true) return;

    Future<void> migrateLegacyValue<T>({
      required String key,
      required T? legacyValue,
      required Future<bool> Function(String scopedKey, T value) writeScoped,
    }) async {
      if (legacyValue == null) return;
      final scopedKey = '${_defaultProfileId}_$key';
      if (!prefs.containsKey(scopedKey)) {
        final success = await writeScoped(scopedKey, legacyValue);
        if (!success) {
          debugPrint(
              'ProfileManager: Failed to migrate legacy pref "$key" to "$scopedKey". Leaving legacy key intact.');
          return;
        }
      }
      await prefs.remove(key);
    }

    const boolKeys = <String>[
      hideAppBarKey,
      useModernUserAgentKey,
      enableGitFetchKey,
      privateBrowsingKey,
      adBlockingKey,
      strictModeKey,
      passwordManagerEnabledKey,
      reorderableTabsKey,
      tabFaviconBadgeEnabledKey,
      aiSearchSuggestionsEnabledKey,
      advancedCacheEnabledKey,
      ambientToolbarEnabledKey,
      urlAutocompleteSuggestionRemovalEnabledKey,
      autoHideAddressBarKey,
    ];

    const stringKeys = <String>[
      homepageKey,
      themeModeKey,
      pageFontFamilyKey,
      pageFontOverridesKey,
      bookmarksStorageKey,
      browsingHistoryKey,
      navigationCacheIndexKey,
    ];

    for (final key in boolKeys) {
      await migrateLegacyValue<bool>(
        key: key,
        legacyValue: prefs.getBool(key),
        writeScoped: prefs.setBool,
      );
    }

    for (final key in stringKeys) {
      await migrateLegacyValue<String>(
        key: key,
        legacyValue: prefs.getString(key),
        writeScoped: prefs.setString,
      );
    }

    await prefs.setBool(_legacySettingsMigratedKey, true);
  }

  Future<UserProfile> createProfile(String name, {int? colorValue}) async {
    final id = 'profile_${DateTime.now().millisecondsSinceEpoch}';
    final profile = UserProfile(
      id: id,
      name: name,
      colorValue: colorValue ??
          UserProfile.availableColors[
              _profiles.length % UserProfile.availableColors.length],
      createdAt: DateTime.now(),
    );
    _profiles.add(profile);
    await _saveProfiles();
    notifyListeners();
    return profile;
  }

  Future<void> updateProfile(UserProfile profile) async {
    final index = _profiles.indexWhere((p) => p.id == profile.id);
    if (index != -1) {
      _profiles[index] = profile;
      await _saveProfiles();
      notifyListeners();
    }
  }

  Future<void> deleteProfile(String id) async {
    if (id == _defaultProfileId) return;

    final index = _profiles.indexWhere((p) => p.id == id);
    if (index == -1) return;

    _profiles.removeAt(index);

    if (_activeProfileId == id) {
      await _setActiveProfileId(_profiles.first.id);
    }

    await _erasePrefsForProfile(id);
    await _saveProfiles();
    notifyListeners();
  }

  Future<void> _erasePrefsForProfile(String profileId) async {
    final prefs = _prefs;
    if (prefs == null) {
      throw StateError(
          'ProfileManager._erasePrefsForProfile: _prefs is null. Call initialize() first.');
    }
    final prefix = '${profileId}_';
    final keysToRemove = prefs
        .getKeys()
        .where((key) => key.startsWith(prefix))
        .toList(growable: false);
    for (final key in keysToRemove) {
      await prefs.remove(key);
    }
  }

  Future<void> switchProfile(String id) async {
    if (_profiles.any((p) => p.id == id) && id != _activeProfileId) {
      await _setActiveProfileId(id);
      notifyListeners();
    }
  }

  bool canDelete(String id) => id != _defaultProfileId;

  String getProfileStorageKey(String key) {
    if (_activeProfileId == null) {
      throw StateError(
          'ProfileManager.getProfileStorageKey: _activeProfileId is null. Call initialize() first.');
    }
    return '${_activeProfileId}_$key';
  }

  /// Returns a profile-scoped key when a profile is active; otherwise returns
  /// the input key unchanged.
  ///
  /// Use this for settings storage in contexts (like widget tests) where the
  /// profile manager may not be initialized.
  String getScopedStorageKey(String key) {
    final id = _activeProfileId;
    if (id == null || id.isEmpty) return key;
    return '${id}_$key';
  }

  String get bookmarksKey => getProfileStorageKey(bookmarksStorageKey);
  String get historyKey => getProfileStorageKey(browsingHistoryKey);

  void resetForTesting() {
    _prefs = null;
    _profiles = [];
    _activeProfileId = null;
    notifyListeners();
  }
}
