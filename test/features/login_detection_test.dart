// SPDX-License-Identifier: MIT
//
// Copyright 2026 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:browser/features/login_detection.dart';

void main() {
  group('LoginCredentials', () {
    test('should create from JSON', () {
      final json = {
        'origin': 'https://example.com',
        'username': 'user@example.com',
        'password': 'secret123',
      };

      final credentials = LoginCredentials.fromJson(json);

      expect(credentials.origin, 'https://example.com');
      expect(credentials.username, 'user@example.com');
      expect(credentials.password, 'secret123');
    });

    test('should create instance with required fields', () {
      const credentials = LoginCredentials(
        origin: 'https://example.com',
        username: 'user@example.com',
        password: 'secret123',
      );

      expect(credentials.origin, 'https://example.com');
      expect(credentials.username, 'user@example.com');
      expect(credentials.password, 'secret123');
    });
  });

  group('loginDetectionScript', () {
    test('should contain LoginDetector channel', () {
      expect(loginDetectionScript.contains('LoginDetector'), true);
    });

    test('should detect password fields', () {
      expect(
        loginDetectionScript.contains('input[type="password"]'),
        true,
      );
    });

    test('should listen for form submit', () {
      expect(loginDetectionScript.contains('submit'), true);
    });

    test('should use MutationObserver for dynamic forms', () {
      expect(loginDetectionScript.contains('MutationObserver'), true);
    });

    test('should send origin from window.location.origin', () {
      expect(loginDetectionScript.contains('window.location.origin'), true);
    });
  });
}
