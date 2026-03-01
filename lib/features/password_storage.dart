// SPDX-License-Identifier: MIT
//
// Copyright 2026 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PasswordCredential {
  const PasswordCredential({
    required this.id,
    required this.origin,
    required this.username,
    required this.password,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String origin;
  final String username;
  final String password;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory PasswordCredential.create({
    required String origin,
    required String username,
    required String password,
  }) {
    final now = DateTime.now().toUtc();
    return PasswordCredential(
      id: _nextCredentialId(),
      origin: origin,
      username: username,
      password: password,
      createdAt: now,
      updatedAt: now,
    );
  }

  PasswordCredential copyWith({
    String? origin,
    String? username,
    String? password,
    DateTime? updatedAt,
  }) {
    return PasswordCredential(
      id: id,
      origin: origin ?? this.origin,
      username: username ?? this.username,
      password: password ?? this.password,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'origin': origin,
        'username': username,
        'password': password,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory PasswordCredential.fromJson(Map<String, dynamic> json) {
    return PasswordCredential(
      id: json['id'] as String,
      origin: json['origin'] as String,
      username: json['username'] as String,
      password: json['password'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
    );
  }
}

String _nextCredentialId() {
  final random = Random.secure().nextInt(1 << 32);
  final micros = DateTime.now().toUtc().microsecondsSinceEpoch;
  return '${micros.toRadixString(16)}-${random.toRadixString(16)}';
}

abstract class SecureKeyValueStore {
  Future<void> write({
    required String key,
    required String value,
  });

  Future<String?> read({
    required String key,
  });

  Future<Map<String, String>> readAll();

  Future<void> delete({
    required String key,
  });
}

class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  const FlutterSecureKeyValueStore({
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<void> write({
    required String key,
    required String value,
  }) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<String?> read({
    required String key,
  }) {
    return _storage.read(key: key);
  }

  @override
  Future<Map<String, String>> readAll() {
    return _storage.readAll();
  }

  @override
  Future<void> delete({
    required String key,
  }) {
    return _storage.delete(key: key);
  }
}

class PasswordStorageRepository {
  PasswordStorageRepository({
    SecureKeyValueStore? store,
  }) : _store = store ?? const FlutterSecureKeyValueStore();

  static const String _credentialPrefix = 'password_credential:';
  final SecureKeyValueStore _store;

  String _storageKey(String id) => '$_credentialPrefix$id';

  Future<void> saveCredential(PasswordCredential credential) async {
    final normalizedCredential = credential.copyWith(
      updatedAt: DateTime.now().toUtc(),
    );
    final payload = jsonEncode(normalizedCredential.toJson());
    await _store.write(
      key: _storageKey(normalizedCredential.id),
      value: payload,
    );
  }

  Future<PasswordCredential?> getCredentialById(String id) async {
    final payload = await _store.read(key: _storageKey(id));
    if (payload == null || payload.isEmpty) return null;
    return _decodeCredential(payload);
  }

  Future<List<PasswordCredential>> listCredentials() async {
    final allValues = await _store.readAll();
    final credentials = allValues.entries
        .where((entry) => entry.key.startsWith(_credentialPrefix))
        .map((entry) => _decodeCredential(entry.value))
        .whereType<PasswordCredential>()
        .toList();
    credentials.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return credentials;
  }

  Future<bool> deleteCredential(String id) async {
    final key = _storageKey(id);
    final existing = await _store.read(key: key);
    if (existing == null) {
      return false;
    }
    await _store.delete(key: key);
    return true;
  }

  Future<void> clearAllCredentials() async {
    final allValues = await _store.readAll();
    final credentialKeys =
        allValues.keys.where((key) => key.startsWith(_credentialPrefix));
    await Future.wait(credentialKeys.map((key) => _store.delete(key: key)));
  }

  PasswordCredential? _decodeCredential(String rawValue) {
    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return PasswordCredential.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }
}
