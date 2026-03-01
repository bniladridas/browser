// SPDX-License-Identifier: MIT
//
// Copyright 2026 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'package:shared_preferences/shared_preferences.dart';

class SitePasswordPolicy {
  SitePasswordPolicy({
    required SharedPreferences prefs,
  }) : _prefs = prefs;

  static const String _neverSavePrefix = 'password_never_save:';
  final SharedPreferences _prefs;

  String _canonicalOrigin(String origin) {
    final uri = Uri.parse(origin);
    return uri.origin;
  }

  Future<void> setNeverSave(String origin) async {
    final canonical = _canonicalOrigin(origin);
    await _prefs.setBool('$_neverSavePrefix$canonical', true);
  }

  Future<bool> isNeverSave(String origin) async {
    final canonical = _canonicalOrigin(origin);
    return _prefs.getBool('$_neverSavePrefix$canonical') ?? false;
  }

  Future<void> clearNeverSave(String origin) async {
    final canonical = _canonicalOrigin(origin);
    await _prefs.remove('$_neverSavePrefix$canonical');
  }
}

class SavePasswordPromptData {
  const SavePasswordPromptData({
    required this.origin,
    required this.username,
    required this.password,
  });

  final String origin;
  final String username;
  final String password;
}
