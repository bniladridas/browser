// SPDX-License-Identifier: MIT
//
// Copyright 2025 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:browser/ux/browser_page.dart';

void main() {
  group('URL Processing', () {
    test('should prepend https to plain domain', () {
      expect(UrlUtils.processUrl('example.com'), 'https://example.com');
    });

    test('should convert search query to Google search URL', () {
      expect(UrlUtils.processUrl('flutter development'),
          'https://www.google.com/search?q=flutter%20development');
    });

    test('should leave valid URLs unchanged', () {
      expect(UrlUtils.processUrl('https://www.google.com'), 'https://www.google.com');
    });

    test('should handle localhost URLs', () {
      expect(UrlUtils.processUrl('localhost:3000'), 'https://localhost:3000');
    });
  });
}