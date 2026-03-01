// SPDX-License-Identifier: MIT
//
// Copyright 2026 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:browser/features/password_autofill.dart';
import 'package:browser/features/password_storage.dart';

class MockPasswordStorageRepository implements PasswordStorageRepository {
  final List<PasswordCredential> _credentials = [];

  @override
  Future<void> saveCredential(PasswordCredential credential) async {
    _credentials.add(credential);
  }

  @override
  Future<List<PasswordCredential>> listCredentials() async {
    return _credentials;
  }

  @override
  Future<PasswordCredential?> getCredentialById(String id) async {
    return _credentials.where((c) => c.id == id).firstOrNull;
  }

  @override
  Future<bool> deleteCredential(String id) async {
    final index = _credentials.indexWhere((c) => c.id == id);
    if (index == -1) return false;
    _credentials.removeAt(index);
    return true;
  }

  @override
  Future<void> clearAllCredentials() async {
    _credentials.clear();
  }
}

void main() {
  group('PasswordAutofillService', () {
    late PasswordAutofillService service;
    late MockPasswordStorageRepository repository;

    setUp(() {
      repository = MockPasswordStorageRepository();
      service = PasswordAutofillService(repository: repository);
    });

    group('originMatches', () {
      test('should match exact same origin', () {
        expect(
          service.originMatches(
            'https://example.com',
            'https://example.com',
          ),
          true,
        );
      });

      test('should match origin with different paths', () {
        expect(
          service.originMatches(
            'https://example.com/login',
            'https://example.com/signin',
          ),
          true,
        );
      });

      test('should not match different schemes', () {
        expect(
          service.originMatches(
            'http://example.com',
            'https://example.com',
          ),
          false,
        );
      });

      test('should not match different hosts', () {
        expect(
          service.originMatches(
            'https://example.com',
            'https://other.com',
          ),
          false,
        );
      });

      test('should not match different ports', () {
        expect(
          service.originMatches(
            'https://example.com:8080',
            'https://example.com:9090',
          ),
          false,
        );
      });

      test('should not match subdomain', () {
        expect(
          service.originMatches(
            'https://example.com',
            'https://sub.example.com',
          ),
          false,
        );
      });

      test('should handle malformed URLs', () {
        expect(
          service.originMatches(
            'not-a-url',
            'https://example.com',
          ),
          false,
        );
      });
    });

    group('getMatchingCredentials', () {
      test('should return credentials with matching origin', () async {
        await repository.saveCredential(
          PasswordCredential.create(
            origin: 'https://example.com',
            username: 'user1',
            password: 'pass1',
          ),
        );
        await repository.saveCredential(
          PasswordCredential.create(
            origin: 'https://other.com',
            username: 'user2',
            password: 'pass2',
          ),
        );

        final matches = await service.getMatchingCredentials(
          'https://example.com/login',
        );

        expect(matches.length, 1);
        expect(matches[0].username, 'user1');
      });

      test('should return empty list when no matches', () async {
        await repository.saveCredential(
          PasswordCredential.create(
            origin: 'https://example.com',
            username: 'user1',
            password: 'pass1',
          ),
        );

        final matches = await service.getMatchingCredentials(
          'https://other.com',
        );

        expect(matches.length, 0);
      });

      test('should return multiple credentials for same origin', () async {
        await repository.saveCredential(
          PasswordCredential.create(
            origin: 'https://example.com',
            username: 'user1',
            password: 'pass1',
          ),
        );
        await repository.saveCredential(
          PasswordCredential.create(
            origin: 'https://example.com',
            username: 'user2',
            password: 'pass2',
          ),
        );

        final matches = await service.getMatchingCredentials(
          'https://example.com',
        );

        expect(matches.length, 2);
      });
    });

    group('generateAutofillScript', () {
      test('should generate script with JSON-encoded credentials', () {
        final script = service.generateAutofillScript(
          "user@example.com",
          "password123",
        );

        expect(script.contains('"user@example.com"'), true);
        expect(script.contains('"password123"'), true);
        expect(script.contains('input[type="password"]'), true);
      });

      test('should properly escape quotes and special characters', () {
        final script = service.generateAutofillScript(
          "user'name",
          'pass"word\\test',
        );

        // jsonEncode wraps in quotes and escapes internal quotes/backslashes
        expect(script.contains('user'), true);
        expect(script.contains('pass'), true);
        // Verify no unescaped quotes that could break JS
        expect(script.contains("'user'name'"), false);
      });
    });
  });
}
