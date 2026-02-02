// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';

import 'package:browser/features/private_browsing.dart';

void main() {
  group('PrivateBrowsingSettings', () {
    test('fromEnabled true', () {
      final settings = PrivateBrowsingSettings.fromEnabled(true);
      expect(settings.cacheEnabled, false);
      expect(settings.clearCache, true);
    });

    test('fromEnabled false', () {
      final settings = PrivateBrowsingSettings.fromEnabled(false);
      expect(settings.cacheEnabled, true);
      expect(settings.clearCache, false);
    });
  });
}
