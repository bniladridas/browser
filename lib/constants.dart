// SPDX-License-Identifier: MIT
//
// Copyright 2026 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

const String homepageKey = 'homepage';
const String hideAppBarKey = 'hideAppBar';
const String useModernUserAgentKey = 'useModernUserAgent';
const String enableGitFetchKey = 'enableGitFetch';
const String privateBrowsingKey = 'privateBrowsing';
const String adBlockingKey = 'adBlocking';
const String strictModeKey = 'strictMode';
const String themeModeKey = 'themeMode';
const String passwordManagerEnabledKey = 'passwordManagerEnabled';
const String reorderableTabsKey = 'reorderableTabs';
const String pageFontFamilyKey = 'pageFontFamily';
const String pageFontOverridesKey = 'pageFontOverrides';
const String bookmarksStorageKey = 'bookmarks';
const String browsingHistoryKey = 'browsingHistory';
const String aiSearchSuggestionsEnabledKey = 'aiSearchSuggestionsEnabled';
const String advancedCacheEnabledKey = 'advancedCacheEnabled';
const String navigationCacheIndexKey = 'navigationCacheIndex';
const String whatsNewSeenVersionKey = 'whatsNewSeenVersion';

const String defaultHomepageUrl = 'about:browser-home';

bool get isIntegrationTest =>
    const bool.fromEnvironment('INTEGRATION_TEST', defaultValue: false);

bool _windowChromeReady = false;

bool get isWindowChromeReady => _windowChromeReady;

void markWindowChromeReady() {
  _windowChromeReady = true;
}
