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

  group('resolveNavigationEventUrl', () {
    test('prefers navigation event URL over stale controller URL', () {
      final resolved = resolveNavigationEventUrl(
        eventUrl: 'https://www.apple.com/',
        controllerUrl: 'https://about.gitlab.com/',
        pendingUrl: 'https://www.apple.com/',
        previousUrl: 'https://about.gitlab.com/',
      );

      expect(resolved, 'https://www.apple.com/');
    });

    test('falls back to controller URL when event URL is about:blank', () {
      final resolved = resolveNavigationEventUrl(
        eventUrl: 'about:blank',
        controllerUrl: 'https://www.apple.com/',
        pendingUrl: 'https://www.apple.com/',
        previousUrl: 'https://about.gitlab.com/',
      );

      expect(resolved, 'https://www.apple.com/');
    });

    test('prefers pending URL when callback still reports previous site', () {
      final resolved = resolveNavigationEventUrl(
        eventUrl: 'https://about.gitlab.com/',
        controllerUrl: null,
        pendingUrl: 'https://apple.com/',
        previousUrl: 'https://about.gitlab.com/',
      );

      expect(resolved, 'https://apple.com/');
    });
  });

  group('shouldReturnHomeOnBack', () {
    test('returns true for the first site family launched from home', () {
      final shouldReturnHome = shouldReturnHomeOnBack(
        currentUrl: 'https://gitlab.com/groups/project/-/issues',
        homeUrl: 'about:browser-home',
        homeLaunchedSiteFamily: 'gitlab.com',
      );

      expect(shouldReturnHome, isTrue);
    });

    test('returns false for a different site family', () {
      final shouldReturnHome = shouldReturnHomeOnBack(
        currentUrl: 'https://www.apple.com/',
        homeUrl: 'about:browser-home',
        homeLaunchedSiteFamily: 'gitlab.com',
      );

      expect(shouldReturnHome, isFalse);
    });

    test('returns false when home is not the internal browser home', () {
      final shouldReturnHome = shouldReturnHomeOnBack(
        currentUrl: 'https://gitlab.com/',
        homeUrl: 'https://example.com/',
        homeLaunchedSiteFamily: 'gitlab.com',
      );

      expect(shouldReturnHome, isFalse);
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

  group('media playback bridge', () {
    test('parses playback state messages', () {
      final state = parseMediaPlaybackStateMessage(
        '{"type":"playback","hasPlayingMedia":true}',
      );

      expect(state, isNotNull);
      expect(state!.hasPlayingMedia, isTrue);
    });

    test('ignores invalid playback messages', () {
      expect(parseMediaPlaybackStateMessage('not-json'), isNull);
      expect(
        parseMediaPlaybackStateMessage(
            '{"type":"other","hasPlayingMedia":true}'),
        isNull,
      );
      expect(
        parseMediaPlaybackStateMessage(
            '{"type":"playback","hasPlayingMedia":"yes"}'),
        isNull,
      );
    });

    test('builds bridge script with mute preference', () {
      final mutedScript = buildMediaBridgeScript(muted: true);
      final unmutedScript = buildMediaBridgeScript(muted: false);

      expect(mutedScript, contains('const desiredMuted = true;'));
      expect(unmutedScript, contains('const desiredMuted = false;'));
      expect(mutedScript, contains('MediaStateChannel.postMessage'));
      expect(mutedScript, contains('MutationObserver'));
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
