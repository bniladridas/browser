// SPDX-License-Identifier: MIT
//
// Copyright 2026 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'package:browser/features/password_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSecureStore implements SecureKeyValueStore {
  final Map<String, String> _values = {};

  @override
  Future<void> write({
    required String key,
    required String value,
  }) async {
    _values[key] = value;
  }

  @override
  Future<String?> read({
    required String key,
  }) async {
    return _values[key];
  }

  @override
  Future<Map<String, String>> readAll() async {
    return Map<String, String>.from(_values);
  }

  @override
  Future<void> delete({
    required String key,
  }) async {
    _values.remove(key);
  }
}

class _ThrowingSecureStore implements SecureKeyValueStore {
  @override
  Future<void> write({
    required String key,
    required String value,
  }) async {
    throw PlatformException(
      code: '-34018',
      message: "A required entitlement isn't present.",
    );
  }

  @override
  Future<String?> read({
    required String key,
  }) async {
    throw PlatformException(
      code: '-34018',
      message: "A required entitlement isn't present.",
    );
  }

  @override
  Future<Map<String, String>> readAll() async {
    throw PlatformException(
      code: '-34018',
      message: "A required entitlement isn't present.",
    );
  }

  @override
  Future<void> delete({
    required String key,
  }) async {
    throw PlatformException(
      code: '-34018',
      message: "A required entitlement isn't present.",
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PasswordCredential', () {
    test('create should populate metadata', () {
      final credential = PasswordCredential.create(
        origin: 'https://accounts.example.com',
        username: 'alice',
        password: 'secret',
      );

      expect(credential.id.isNotEmpty, true);
      expect(credential.origin, 'https://accounts.example.com');
      expect(credential.username, 'alice');
      expect(credential.password, 'secret');
      expect(credential.updatedAt.isBefore(credential.createdAt), false);
    });

    test('should serialize and deserialize', () {
      final credential = PasswordCredential(
        id: 'abc',
        origin: 'https://example.com',
        username: 'user',
        password: 'pw',
        createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
        updatedAt: DateTime.parse('2026-03-01T01:00:00Z'),
      );

      final decoded = PasswordCredential.fromJson(credential.toJson());

      expect(decoded.id, credential.id);
      expect(decoded.origin, credential.origin);
      expect(decoded.username, credential.username);
      expect(decoded.password, credential.password);
      expect(decoded.createdAt, credential.createdAt);
      expect(decoded.updatedAt, credential.updatedAt);
    });
  });

  group('PasswordStorageRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('save and fetch credential by id', () async {
      final store = _FakeSecureStore();
      final repo = PasswordStorageRepository(store: store);
      final credential = PasswordCredential.create(
        origin: 'https://example.com',
        username: 'bob',
        password: 'pw1',
      );

      await repo.saveCredential(credential);
      final loaded = await repo.getCredentialById(credential.id);

      expect(loaded, isNotNull);
      expect(loaded!.origin, 'https://example.com');
      expect(loaded.username, 'bob');
    });

    test(
        'listCredentials should include only credential keys and sort by updatedAt',
        () async {
      final store = _FakeSecureStore();
      final repo = PasswordStorageRepository(store: store);
      await store.write(key: 'misc:key', value: 'not-a-credential');

      final older = PasswordCredential(
        id: 'old',
        origin: 'https://old.example',
        username: 'old',
        password: 'old',
        createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
        updatedAt: DateTime.parse('2026-03-01T00:00:00Z'),
      );
      final newer = PasswordCredential(
        id: 'new',
        origin: 'https://new.example',
        username: 'new',
        password: 'new',
        createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
        updatedAt: DateTime.parse('2026-03-01T02:00:00Z'),
      );

      await repo.saveCredential(older);
      await repo.saveCredential(newer);

      final all = await repo.listCredentials();
      expect(all.length, 2);
      expect(all.first.id, 'new');
      expect(all.last.id, 'old');
    });

    test('listCredentials should migrate legacy stored credentials into index',
        () async {
      final store = _FakeSecureStore();
      final repo = PasswordStorageRepository(store: store);
      final legacy = PasswordCredential(
        id: 'legacy',
        origin: 'https://example.com',
        username: 'alice',
        password: 'pw',
        createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
        updatedAt: DateTime.parse('2026-03-01T00:00:00Z'),
      );

      await store.write(
        key: 'password_credential:${legacy.id}',
        value:
            '{"id":"legacy","origin":"https://example.com","username":"alice","password":"pw","createdAt":"2026-03-01T00:00:00.000Z","updatedAt":"2026-03-01T00:00:00.000Z"}',
      );

      final loaded = await repo.listCredentials();

      expect(loaded, hasLength(1));
      expect(loaded.first.id, legacy.id);
      expect(await store.read(key: 'password_credential:index'), '["legacy"]');
    });

    test('deleteCredential should return false for missing id', () async {
      final repo = PasswordStorageRepository(store: _FakeSecureStore());
      final deleted = await repo.deleteCredential('missing');
      expect(deleted, false);
    });

    test('clearAllCredentials should only remove credential records', () async {
      final store = _FakeSecureStore();
      final repo = PasswordStorageRepository(store: store);

      final credential = PasswordCredential.create(
        origin: 'https://example.com',
        username: 'sam',
        password: 'pw',
      );
      await repo.saveCredential(credential);
      await store.write(key: 'other:key', value: 'keep');

      await repo.clearAllCredentials();

      expect(await repo.getCredentialById(credential.id), isNull);
      expect(await store.read(key: 'other:key'), 'keep');
    });

    test('should fall back when secure storage fails in debug mode', () async {
      final repo = PasswordStorageRepository(
        store: ResilientSecureKeyValueStore(
          primary: _ThrowingSecureStore(),
          fallback: const SharedPreferencesKeyValueStore(prefix: 'test:'),
          enableFallback: true,
        ),
      );

      final credential = PasswordCredential.create(
        origin: 'https://example.com',
        username: 'debug-user',
        password: 'pw',
      );

      await repo.saveCredential(credential);
      final loaded = await repo.listCredentials();

      expect(loaded, hasLength(1));
      expect(loaded.first.username, 'debug-user');
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('test:password_credential:index'),
        contains(credential.id),
      );
    });

    test('should isolate credentials by namespace', () async {
      final store = _FakeSecureStore();
      final workRepo = PasswordStorageRepository(
        store: store,
        namespaceProvider: () => 'work',
      );
      final personalRepo = PasswordStorageRepository(
        store: store,
        namespaceProvider: () => 'personal',
      );

      await workRepo.saveCredential(
        PasswordCredential.create(
          origin: 'https://example.com',
          username: 'work-user',
          password: 'pw1',
        ),
      );
      await personalRepo.saveCredential(
        PasswordCredential.create(
          origin: 'https://example.com',
          username: 'personal-user',
          password: 'pw2',
        ),
      );

      final workCredentials = await workRepo.listCredentials();
      final personalCredentials = await personalRepo.listCredentials();

      expect(workCredentials, hasLength(1));
      expect(workCredentials.first.username, 'work-user');
      expect(personalCredentials, hasLength(1));
      expect(personalCredentials.first.username, 'personal-user');
    });
  });
}
