// SPDX-License-Identifier: MIT
//
// Copyright 2026 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:browser/ux/password_vault_screen.dart';
import 'package:browser/features/password_storage.dart';

class MockPasswordStorageRepository implements PasswordStorageRepository {
  final List<PasswordCredential> _credentials = [];

  @override
  Future<void> saveCredential(PasswordCredential credential) async {
    _credentials.add(credential);
  }

  @override
  Future<List<PasswordCredential>> listCredentials() async {
    return List.from(_credentials);
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
  group('PasswordVaultScreen', () {
    late MockPasswordStorageRepository mockRepository;

    setUp(() {
      mockRepository = MockPasswordStorageRepository();
    });

    testWidgets('should display title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PasswordVaultScreen(repository: mockRepository),
        ),
      );

      expect(find.text('Password Vault'), findsOneWidget);
    });

    testWidgets('should display search field', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PasswordVaultScreen(repository: mockRepository),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search'), findsOneWidget);
    });

    testWidgets('should show loading indicator initially', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PasswordVaultScreen(repository: mockRepository),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should show empty state when no passwords', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PasswordVaultScreen(repository: mockRepository),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No saved passwords'), findsOneWidget);
      expect(find.byIcon(Icons.delete_sweep), findsNothing);
    });

    testWidgets('should display list of credentials', (tester) async {
      await mockRepository.saveCredential(
        PasswordCredential.create(
          origin: 'https://example.com',
          username: 'user@example.com',
          password: 'password123',
        ),
      );
      await mockRepository.saveCredential(
        PasswordCredential.create(
          origin: 'https://test.com',
          username: 'test@test.com',
          password: 'test123',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PasswordVaultScreen(repository: mockRepository),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('https://example.com'), findsOneWidget);
      expect(find.text('user@example.com'), findsOneWidget);
      expect(find.text('https://test.com'), findsOneWidget);
      expect(find.text('test@test.com'), findsOneWidget);
      expect(find.byIcon(Icons.delete_sweep), findsOneWidget);
    });

    testWidgets('should filter credentials by search query', (tester) async {
      await mockRepository.saveCredential(
        PasswordCredential.create(
          origin: 'https://example.com',
          username: 'user@example.com',
          password: 'password123',
        ),
      );
      await mockRepository.saveCredential(
        PasswordCredential.create(
          origin: 'https://test.com',
          username: 'test@test.com',
          password: 'test123',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PasswordVaultScreen(repository: mockRepository),
        ),
      );

      await tester.pumpAndSettle();

      // Enter search query
      await tester.enterText(find.byType(TextField), 'example');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('https://example.com'), findsOneWidget);
      expect(find.text('https://test.com'), findsNothing);
    });

    testWidgets('should show no matching message when search has no results',
        (tester) async {
      await mockRepository.saveCredential(
        PasswordCredential.create(
          origin: 'https://example.com',
          username: 'user@example.com',
          password: 'password123',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PasswordVaultScreen(repository: mockRepository),
        ),
      );

      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'nonexistent');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('No matching passwords'), findsOneWidget);
    });
  });
}
