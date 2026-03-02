// SPDX-License-Identifier: MIT
//
// Copyright 2026 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '../constants.dart';

class MasterPasswordService {
  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuth;

  MasterPasswordService({FlutterSecureStorage? storage, LocalAuthentication? localAuth})
      : _storage = storage ?? const FlutterSecureStorage(
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            ),
        _localAuth = localAuth ?? LocalAuthentication();

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<bool> canUseBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics && await _localAuth.isDeviceSupported();
    } catch (e) {
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Authenticate to access your passwords',
      );
    } catch (e) {
      return false;
    }
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
