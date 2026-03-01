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

  Future<void> setNeverSave(String origin) async {
    await _prefs.setBool('$_neverSavePrefix$origin', true);
  }

  Future<bool> isNeverSave(String origin) async {
    return _prefs.getBool('$_neverSavePrefix$origin') ?? false;
  }

  Future<void> clearNeverSave(String origin) async {
    await _prefs.remove('$_neverSavePrefix$origin');
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

