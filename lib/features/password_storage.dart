// SPDX-License-Identifier: MIT
//
// Copyright 2026 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class SharedPreferencesKeyValueStore implements SecureKeyValueStore {
  const SharedPreferencesKeyValueStore({
    this.prefix = 'debug_password_store:',
  });

  @Deprecated(
      'Stores passwords in plaintext. Use only for development/testing or as encrypted fallback.')
  final String prefix;

  String _key(String key) => '$prefix$key';

  @override
  Future<void> write({
    required String key,
    required String value,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(key), value);
  }

  @override
  Future<String?> read({
    required String key,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key(key));
  }

  @override
  Future<Map<String, String>> readAll() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs
        .getKeys()
        .where((key) => key.startsWith(prefix))
        .fold<Map<String, String>>(<String, String>{}, (all, key) {
      final value = prefs.getString(key);
      if (value != null) {
        all[key.substring(prefix.length)] = value;
      }
      return all;
    });
  }

  @override
  Future<void> delete({
    required String key,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(key));
  }
}

class ResilientSecureKeyValueStore implements SecureKeyValueStore {
  static const String _fallbackPreferenceKey = 'use_fallback';

  ResilientSecureKeyValueStore({
    required SecureKeyValueStore primary,
    required SecureKeyValueStore fallback,
    bool? enableFallback,
  })  : _primary = primary,
        _fallback = fallback,
        _enableFallback = enableFallback ?? (kDebugMode && Platform.isMacOS);

  final SecureKeyValueStore _primary;
  final SecureKeyValueStore _fallback;
  final bool _enableFallback;
  bool _fallbackActive = false;
  bool _initialized = false;

  bool get isUsingFallback => _fallbackActive;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;
    if (!_enableFallback) return;

    try {
      final stored = await _fallback.read(key: _fallbackPreferenceKey);
      _fallbackActive = stored == 'true';
    } catch (_) {
      _fallbackActive = false;
    }
  }

  Future<T> _run<T>({
    required Future<T> Function(SecureKeyValueStore store) primary,
    required Future<T> Function(SecureKeyValueStore store) fallback,
  }) async {
    await _ensureInitialized();
    if (_fallbackActive) {
      return fallback(_fallback);
    }

    try {
      return await primary(_primary);
    } on PlatformException {
      if (!_enableFallback) rethrow;
      _fallbackActive = true;
      await _fallback.write(key: _fallbackPreferenceKey, value: 'true');
      return fallback(_fallback);
    }
  }

  @override
  Future<void> write({
    required String key,
    required String value,
  }) {
    return _run<void>(
      primary: (store) => store.write(key: key, value: value),
      fallback: (store) => store.write(key: key, value: value),
    );
  }

  @override
  Future<String?> read({
    required String key,
  }) {
    return _run<String?>(
      primary: (store) => store.read(key: key),
      fallback: (store) => store.read(key: key),
    );
  }

  @override
  Future<Map<String, String>> readAll() {
    return _run<Map<String, String>>(
      primary: (store) => store.readAll(),
      fallback: (store) => store.readAll(),
    );
  }

  @override
  Future<void> delete({
    required String key,
  }) {
    return _run<void>(
      primary: (store) => store.delete(key: key),
      fallback: (store) => store.delete(key: key),
    );
  }
}

class PasswordStorageRepository {
  PasswordStorageRepository({
    SecureKeyValueStore? store,
    String Function()? namespaceProvider,
  })  : _store = store ?? _defaultStore(),
        _namespaceProvider = namespaceProvider;

  static const String _credentialPrefix = 'password_credential:';
  static const String _credentialIndexKey = 'password_credential:index';
  static const String _defaultNamespace = 'default';
  final SecureKeyValueStore _store;
  final String Function()? _namespaceProvider;

  static SecureKeyValueStore _defaultStore() {
    if (kDebugMode && Platform.isMacOS) {
      return const SharedPreferencesKeyValueStore();
    }
    return ResilientSecureKeyValueStore(
      primary: const FlutterSecureKeyValueStore(),
      fallback: const SharedPreferencesKeyValueStore(),
    );
  }

  String? get _namespace {
    final callResult = _namespaceProvider?.call();
    final raw = callResult?.trim();
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }

  String _namespacedKey(String key, {String? namespace}) {
    final resolved = namespace ?? _namespace;
    if (resolved == null) return key;
    return '$resolved:$key';
  }

  String _storageKey(String id, {String? namespace}) =>
      _namespacedKey('$_credentialPrefix$id', namespace: namespace);

  String _indexKey({String? namespace}) =>
      _namespacedKey(_credentialIndexKey, namespace: namespace);

  Future<void> saveCredential(PasswordCredential credential) async {
    final normalizedCredential = credential.copyWith(
      updatedAt: DateTime.now().toUtc(),
    );
    final payload = jsonEncode(normalizedCredential.toJson());
    await _store.write(
      key: _storageKey(normalizedCredential.id),
      value: payload,
    );
    final ids = await _loadCredentialIds();
    if (!ids.contains(normalizedCredential.id)) {
      ids.add(normalizedCredential.id);
      await _saveCredentialIds(ids);
    }
  }

  Future<PasswordCredential?> getCredentialById(String id) async {
    final payload = await _store.read(key: _storageKey(id));
    if (payload == null || payload.isEmpty) return null;
    return _decodeCredential(payload);
  }

  Future<List<PasswordCredential>> listCredentials() async {
    final ids = await _loadCredentialIds();
    final credentials = <PasswordCredential>[];
    var idsChanged = false;

    for (final id in ids) {
      final credential = await getCredentialById(id);
      if (credential == null) {
        idsChanged = true;
        continue;
      }
      credentials.add(credential);
    }

    if (idsChanged) {
      final existingIds =
          credentials.map((credential) => credential.id).toList();
      await _saveCredentialIds(existingIds);
    }

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
    final ids = await _loadCredentialIds();
    final removed = ids.remove(id);
    if (removed) {
      await _saveCredentialIds(ids);
    }
    return true;
  }

  Future<void> clearAllCredentials() async {
    final namespace = _namespace;
    final indexKey = _indexKey(namespace: namespace);
    final rawIndex = await _store.read(key: indexKey);
    if (rawIndex == null || rawIndex.isEmpty) {
      return;
    }
    List<String> ids;
    try {
      final decoded = jsonDecode(rawIndex);
      if (decoded is List) {
        ids = decoded.whereType<String>().toList();
      } else {
        return;
      }
    } catch (_) {
      return;
    }
    await Future.wait(ids.map((id) async {
      await _store.delete(key: _storageKey(id));
    }));
    await _store.delete(key: _indexKey(namespace: namespace));

    if (namespace == _defaultNamespace) {
      await _store.delete(key: _credentialIndexKey);
      final allValues = await _store.readAll();
      for (final key in allValues.keys) {
        if (key.startsWith(_credentialPrefix)) {
          await _store.delete(key: key);
        }
      }
    }
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

  Future<List<String>> _loadCredentialIds() async {
    final namespace = _namespace;
    final rawIndex = await _store.read(key: _indexKey(namespace: namespace));
    if (rawIndex != null && rawIndex.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawIndex);
        if (decoded is List) {
          final ids = decoded.whereType<String>().toList();
          if (ids.isNotEmpty) {
            return ids.toSet().toList();
          }
        }
      } catch (_) {
        // Fall back to legacy scan below.
      }
    }

    if (namespace == _defaultNamespace) {
      final legacyRawIndex = await _store.read(key: _credentialIndexKey);
      if (legacyRawIndex != null && legacyRawIndex.isNotEmpty) {
        try {
          final decoded = jsonDecode(legacyRawIndex);
          if (decoded is List) {
            final ids = decoded.whereType<String>().toList();
            if (ids.isNotEmpty) {
              for (final id in ids) {
                final legacyPayload =
                    await _store.read(key: '$_credentialPrefix$id');
                if (legacyPayload != null) {
                  await _store.write(
                    key: _storageKey(id, namespace: namespace),
                    value: legacyPayload,
                  );
                }
              }
              await _saveCredentialIds(ids);
              return ids.toSet().toList();
            }
          }
        } catch (_) {
          // Fall through to scan below.
        }
      }
    }

    final allValues = await _store.readAll();
    final keyPrefix = _namespace == null
        ? _credentialPrefix
        : '${_namespace!}:$_credentialPrefix';
    final legacyIds = allValues.keys
        .where((key) => key.startsWith(keyPrefix))
        .map((key) => key.substring(keyPrefix.length))
        .toSet()
        .toList();
    if (legacyIds.isNotEmpty) {
      await _saveCredentialIds(legacyIds);
    }
    return legacyIds;
  }

  Future<void> _saveCredentialIds(List<String> ids) {
    return _store.write(
      key: _indexKey(),
      value: jsonEncode(ids.toSet().toList()),
    );
  }
}
