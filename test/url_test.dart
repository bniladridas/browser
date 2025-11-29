// SPDX-License-Identifier: MIT
//
// Copyright 2025 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('URL Processing', () {
    test('should prepend https to plain domain', () {
      // Simulate the logic from _loadUrl
      String url = 'example.com';
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        if (url.contains(' ') ||
            (!url.contains('.') &&
                !url.contains(':') &&
                url.toLowerCase() != 'localhost')) {
          url = 'https://www.google.com/search?q=${Uri.encodeComponent(url)}';
        } else {
          url = 'https://$url';
        }
      }
      expect(url, 'https://example.com');
    });

    test('should convert search query to Google search URL', () {
      String url = 'flutter development';
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        if (url.contains(' ') ||
            (!url.contains('.') &&
                !url.contains(':') &&
                url.toLowerCase() != 'localhost')) {
          url = 'https://www.google.com/search?q=${Uri.encodeComponent(url)}';
        } else {
          url = 'https://$url';
        }
      }
      expect(url, 'https://www.google.com/search?q=flutter%20development');
    });

    test('should leave valid URLs unchanged', () {
      String url = 'https://www.google.com';
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        if (url.contains(' ') ||
            (!url.contains('.') &&
                !url.contains(':') &&
                url.toLowerCase() != 'localhost')) {
          url = 'https://www.google.com/search?q=${Uri.encodeComponent(url)}';
        } else {
          url = 'https://$url';
        }
      }
      expect(url, 'https://www.google.com');
    });

    test('should handle localhost URLs', () {
      String url = 'localhost:3000';
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        if (url.contains(' ') ||
            (!url.contains('.') &&
                !url.contains(':') &&
                url.toLowerCase() != 'localhost')) {
          url = 'https://www.google.com/search?q=${Uri.encodeComponent(url)}';
        } else {
          url = 'https://$url';
        }
      }
      expect(url, 'https://localhost:3000');
    });
  });
}