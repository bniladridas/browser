// SPDX-License-Identifier: MIT
//
// Copyright 2026 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:browser/features/update_service.dart';

void main() {
  group('UpdateService', () {
    final updateService = UpdateService();

    group('isNewer', () {
      test('detects patch version increase', () {
        expect(updateService.isNewer('1.0.0', '1.0.1'), isTrue);
      });

      test('detects minor version increase', () {
        expect(updateService.isNewer('1.0.0', '1.1.0'), isTrue);
      });

      test('detects major version increase', () {
        expect(updateService.isNewer('1.0.0', '2.0.0'), isTrue);
      });

      test('returns false for same version', () {
        expect(updateService.isNewer('1.2.3', '1.2.3'), isFalse);
      });

      test('returns false for older patch version', () {
        expect(updateService.isNewer('1.2.3', '1.2.2'), isFalse);
      });

      test('returns false for older minor version', () {
        expect(updateService.isNewer('1.2.3', '1.1.9'), isFalse);
      });

      test('returns false for older major version', () {
        expect(updateService.isNewer('2.0.0', '1.9.9'), isFalse);
      });

      test('handles different number of parts - shorter current', () {
        expect(updateService.isNewer('1.0', '1.0.1'), isTrue);
      });

      test('handles different number of parts - shorter latest', () {
        expect(updateService.isNewer('1.0.1', '1.1'), isTrue);
      });

      test('handles equal versions with different parts', () {
        expect(updateService.isNewer('1.1.0', '1.1'), isFalse);
      });

      test('handles non-numeric parts gracefully', () {
        expect(updateService.isNewer('1.0.0', '1.0.1-beta'), isTrue);
      });

      test('handles pre-release versions', () {
        expect(updateService.isNewer('1.0.0', '1.0.0-alpha'), isFalse);
      });

      test('handles leading v in current version', () {
        expect(updateService.isNewer('v1.0.0', '1.0.1'), isTrue);
      });

      test('handles build metadata', () {
        expect(updateService.isNewer('1.0.0+build1', '1.0.1'), isTrue);
      });

      test('handles completely invalid latest version', () {
        expect(updateService.isNewer('1.0.0', 'invalid'), isFalse);
      });

      test('handles completely invalid current version', () {
        expect(updateService.isNewer('invalid', '1.0.0'), isFalse);
      });

      test('compares multi-part versions correctly', () {
        expect(updateService.isNewer('1.0.0', '1.0.0.1'), isTrue);
        expect(updateService.isNewer('1.0.0.1', '1.0.1'), isTrue);
        expect(updateService.isNewer('1.0.0.0', '1.0.0'), isFalse);
      });
    });

    group('version regex', () {
      test('extracts version from v-prefixed tag', () {
        final regex = RegExp(r'v?(\d+(?:\.\d+)+)');
        expect(regex.firstMatch('v1.2.3')?.group(1), '1.2.3');
      });

      test('extracts version from app-prefixed tag', () {
        final regex = RegExp(r'v?(\d+(?:\.\d+)+)');
        expect(regex.firstMatch('app-1.2.3')?.group(1), '1.2.3');
      });

      test('extracts version from plain tag', () {
        final regex = RegExp(r'v?(\d+(?:\.\d+)+)');
        expect(regex.firstMatch('1.2.3')?.group(1), '1.2.3');
      });

      test('extracts version from complex tag', () {
        final regex = RegExp(r'v?(\d+(?:\.\d+)+)');
        expect(regex.firstMatch('release/v2.0.1-beta')?.group(1), '2.0.1');
      });

      test('returns null for invalid version tag', () {
        final regex = RegExp(r'v?(\d+(?:\.\d+)+)');
        expect(regex.firstMatch('invalid'), isNull);
      });
    });
  });
}
