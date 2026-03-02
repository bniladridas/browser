// SPDX-License-Identifier: MIT
//
// Copyright 2026 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants.dart';

class MasterPasswordService {
  final FlutterSecureStorage _storage;

  MasterPasswordService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage(
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<bool> hasMasterPassword() async {
    final hash = await _storage.read(key: masterPasswordHashKey);
    return hash != null;
  }

  Future<void> setMasterPassword(String password) async {
    final hash = _hashPassword(password);
    await _storage.write(key: masterPasswordHashKey, value: hash);
  }

  Future<bool> verifyMasterPassword(String password) async {
    final storedHash = await _storage.read(key: masterPasswordHashKey);
    if (storedHash == null) return false;
    final inputHash = _hashPassword(password);
    return storedHash == inputHash;
  }

  Future<void> removeMasterPassword() async {
    await _storage.delete(key: masterPasswordHashKey);
  }
}
