// SPDX-License-Identifier: MIT
//
// Copyright 2026 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'package:browser/ux/browser_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveUrlSubmission', () {
    test('loads trimmed URL when submitted value is non-empty', () {
      final decision = resolveUrlSubmission(
        submittedValue: '  https://example.com  ',
        aiSearchSuggestionsEnabled: true,
      );

      expect(decision.normalizedInput, 'https://example.com');
      expect(decision.shouldLoadUrl, isTrue);
      expect(decision.shouldShowAiSuggestions, isFalse);
    });

    test('shows AI suggestions for empty input when feature is enabled', () {
      final decision = resolveUrlSubmission(
        submittedValue: '   ',
        aiSearchSuggestionsEnabled: true,
      );

      expect(decision.normalizedInput, isEmpty);
      expect(decision.shouldLoadUrl, isFalse);
      expect(decision.shouldShowAiSuggestions, isTrue);
    });

    test('does nothing for empty input when AI suggestions are disabled', () {
      final decision = resolveUrlSubmission(
        submittedValue: '',
        aiSearchSuggestionsEnabled: false,
      );

      expect(decision.normalizedInput, isEmpty);
      expect(decision.shouldLoadUrl, isFalse);
      expect(decision.shouldShowAiSuggestions, isFalse);
    });
  });

  group('FaviconUrlPolicy', () {
    test('parses escaped JS string favicon result', () {
      final resolved = FaviconUrlPolicy.resolveFaviconFromJsResult(
        r'"https:\/\/example.com\/favicon.ico"',
      );

      expect(resolved, 'https://example.com/favicon.ico');
    });

    test('returns null for null/undefined JS string results', () {
      expect(FaviconUrlPolicy.resolveFaviconFromJsResult('null'), isNull);
      expect(FaviconUrlPolicy.resolveFaviconFromJsResult('undefined'), isNull);
    });

    test('accepts safe external favicon URLs', () {
      expect(
        FaviconUrlPolicy.isSafeFaviconUrl('https://example.com/favicon.ico'),
        isTrue,
      );
      expect(
        FaviconUrlPolicy.isSafeAndRenderableFaviconUrl(
          'https://example.com/favicon.png',
        ),
        isTrue,
      );
    });

    test('rejects favicon SSRF/local network targets', () {
      expect(
        FaviconUrlPolicy.isSafeFaviconUrl('http://127.0.0.1/favicon.ico'),
        isFalse,
      );
      expect(
        FaviconUrlPolicy.isSafeFaviconUrl(
          'http://169.254.169.254/latest/meta-data',
        ),
        isFalse,
      );
      expect(
        FaviconUrlPolicy.isSafeFaviconUrl('http://10.0.0.10/favicon.ico'),
        isFalse,
      );
      expect(
        FaviconUrlPolicy.isSafeFaviconUrl('https://[::1]/favicon.ico'),
        isFalse,
      );
    });

    test('rejects non-renderable icon extensions and unsafe schemes', () {
      expect(
        FaviconUrlPolicy.isSafeAndRenderableFaviconUrl(
          'https://example.com/favicon.svg',
        ),
        isFalse,
      );
      expect(
        FaviconUrlPolicy.isSafeAndRenderableFaviconUrl(
          'data:image/png;base64,abcd',
        ),
        isFalse,
      );
    });

    test('allows google s2 favicon endpoint as renderable', () {
      expect(
        FaviconUrlPolicy.isSafeAndRenderableFaviconUrl(
          'https://www.google.com/s2/favicons?domain=example.com',
        ),
        isTrue,
      );
    });
  });

  group('Theme probe parsing', () {
    test('parses hsl colors', () {
      final color = parseThemeCssColor('hsl(210 100% 50%)');

      expect(color, isNotNull);
      expect(color, const Color(0xFF0080FF));
    });

    test('parses named colors', () {
      final color = parseThemeCssColor('rebeccapurple');

      expect(color, const Color(0xFF663399));
    });

    test('prefers reliable accent/theme color over neutral backgrounds', () {
      final decision = resolveThemeProbeDecision({
        'sampleBg': 'rgb(255, 255, 255)',
        'bg': 'rgb(255, 255, 255)',
        'themeColor': '#ffffff',
        'accentHint': 'rgb(9, 105, 218)',
      });

      expect(decision, isNotNull);
      expect(decision!.seedColor, const Color(0xFF0969DA));
    });

    test('uses color-scheme when no parseable colors exist', () {
      final decision = resolveThemeProbeDecision({
        'themeColor': 'none',
        'metaColorScheme': 'dark',
      });

      expect(decision, isNotNull);
      expect(decision!.brightness, Brightness.dark);
      expect(decision.seedColor, isNull);
    });
  });
}
