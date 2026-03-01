// SPDX-License-Identifier: MIT
//
// Copyright 2026 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:browser/features/password_prompt.dart';

void main() {
  group('SitePasswordPolicy', () {
    late SharedPreferences prefs;
    late SitePasswordPolicy policy;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      policy = SitePasswordPolicy(prefs: prefs);
    });

    test('should return false for new origin', () async {
      expect(await policy.isNeverSave('https://example.com'), false);
    });

    test('should set and retrieve never-save policy', () async {
      await policy.setNeverSave('https://example.com');
      expect(await policy.isNeverSave('https://example.com'), true);
    });

    test('should clear never-save policy', () async {
      await policy.setNeverSave('https://example.com');
      await policy.clearNeverSave('https://example.com');
      expect(await policy.isNeverSave('https://example.com'), false);
    });

    test('should handle multiple origins independently', () async {
      await policy.setNeverSave('https://example.com');
      await policy.setNeverSave('https://test.com');

      expect(await policy.isNeverSave('https://example.com'), true);
      expect(await policy.isNeverSave('https://test.com'), true);
      expect(await policy.isNeverSave('https://other.com'), false);
    });

    test('should canonicalize origins with paths and trailing slashes',
        () async {
      await policy.setNeverSave('https://example.com/login');
      expect(await policy.isNeverSave('https://example.com'), true);
      expect(await policy.isNeverSave('https://example.com/'), true);
      expect(await policy.isNeverSave('https://example.com/other'), true);
    });
  });

  group('SavePasswordPromptData', () {
    test('should create instance with required fields', () {
      const data = SavePasswordPromptData(
        origin: 'https://example.com',
        username: 'user@example.com',
        password: 'secret123',
      );

      expect(data.origin, 'https://example.com');
      expect(data.username, 'user@example.com');
      expect(data.password, 'secret123');
    });
  });
}
