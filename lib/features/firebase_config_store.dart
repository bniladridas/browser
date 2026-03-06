// SPDX-License-Identifier: MIT
//
// Copyright 2026 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';

class FirebaseConfigStore {
  FirebaseConfigStore._();

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const Duration _secureReadTimeout = Duration(milliseconds: 150);

  static const List<String> _keys = <String>[
    firebaseApiKeyPref,
    firebaseAppIdPref,
    firebaseSenderIdPref,
    firebaseProjectIdPref,
    firebaseStorageBucketPref,
  ];

  static bool _isNonEmpty(String? value) =>
      value != null && value.trim().isNotEmpty;

  static bool _hasAny(Map<String, String?> values) =>
      values.values.any(_isNonEmpty);

  static bool _hasAll(Map<String, String?> values) =>
      values.values.every(_isNonEmpty);

  static Map<String, String> _normalize(Map<String, String?> values) {
    return values.map((k, v) => MapEntry(k, (v ?? '').trim()));
  }

  static Future<Map<String, String?>> _readSecureValues() async {
    final values = <String, String?>{};
    try {
      for (final key in _keys) {
        values[key] = await _secureStorage
            .read(key: key)
            .timeout(_secureReadTimeout, onTimeout: () => null);
      }
    } catch (_) {
      // Secure storage may be unavailable in some environments.
      for (final key in _keys) {
        values[key] = null;
      }
    }
    return values;
  }

  static Future<void> _writeSecureValues(Map<String, String> values) async {
    for (final key in _keys) {
      await _secureStorage.write(key: key, value: values[key] ?? '');
    }
  }

  static Future<void> _removeLegacyPrefsKeys(SharedPreferences prefs) async {
    for (final key in _keys) {
      await prefs.remove(key);
    }
  }

  static Map<String, String?> _readPrefsValues(SharedPreferences prefs) {
    final values = <String, String?>{};
    for (final key in _keys) {
      values[key] = prefs.getString(key);
    }
    return values;
  }

  /// Secure-first read for runtime Firebase config.
  /// Falls back to legacy SharedPreferences values and migrates them.
  static Future<Map<String, String>> loadRuntimeConfig() async {
    final secureValues = await _readSecureValues();
    if (_hasAny(secureValues) && _hasAll(secureValues)) {
      return _normalize(secureValues);
    }

    final prefs = await SharedPreferences.getInstance();
    final legacyValues = _readPrefsValues(prefs);
    if (_hasAny(legacyValues) && _hasAll(legacyValues)) {
      final normalized = _normalize(legacyValues);
      try {
        await _writeSecureValues(normalized);
        await _removeLegacyPrefsKeys(prefs);
      } catch (_) {
        // Keep legacy values when secure storage is unavailable.
      }
      return normalized;
    }

    return {};
  }

  /// Read Firebase settings values for UI fields.
  static Future<Map<String, String>> loadSettingsConfig() async {
    final secureValues = await _readSecureValues();
    final prefs = await SharedPreferences.getInstance();
    final legacyValues = _readPrefsValues(prefs);

    final hasSecureAny = _hasAny(secureValues);
    final hasSecureAll = _hasAll(secureValues);

    if (hasSecureAny && hasSecureAll) {
      return _normalize(secureValues);
    }

    if (_hasAny(legacyValues)) {
      final normalized = _normalize(legacyValues);
      // Best-effort migration, but never block UI if secure storage fails.
      try {
        await _writeSecureValues(normalized);
        await _removeLegacyPrefsKeys(prefs);
      } catch (_) {}
      return normalized;
    }

    return _normalize({
      firebaseApiKeyPref: secureValues[firebaseApiKeyPref],
      firebaseAppIdPref: secureValues[firebaseAppIdPref],
      firebaseSenderIdPref: secureValues[firebaseSenderIdPref],
      firebaseProjectIdPref: secureValues[firebaseProjectIdPref],
      firebaseStorageBucketPref: secureValues[firebaseStorageBucketPref],
    });
  }

  /// Save Firebase settings securely.
  /// Falls back to SharedPreferences only if secure storage is unavailable.
  static Future<void> saveSettingsConfig({
    required String apiKey,
    required String appId,
    required String senderId,
    required String projectId,
    required String storageBucket,
  }) async {
    final values = <String, String>{
      firebaseApiKeyPref: apiKey.trim(),
      firebaseAppIdPref: appId.trim(),
      firebaseSenderIdPref: senderId.trim(),
      firebaseProjectIdPref: projectId.trim(),
      firebaseStorageBucketPref: storageBucket.trim(),
    };

    try {
      await _writeSecureValues(values);
      // Secure write succeeded. Best-effort cleanup for legacy prefs.
      try {
        final prefs = await SharedPreferences.getInstance();
        await _removeLegacyPrefsKeys(prefs);
      } catch (_) {
        // Ignore cleanup errors to avoid downgrading back to plain prefs.
      }
      return;
    } catch (_) {
      // Fallback for environments where secure storage is unavailable.
    }

    final prefs = await SharedPreferences.getInstance();
    for (final entry in values.entries) {
      await prefs.setString(entry.key, entry.value);
    }
  }
}
