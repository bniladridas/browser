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
const String ambientToolbarEnabledKey = 'ambientToolbarEnabled';
const String tabFaviconBadgeEnabledKey = 'tabFaviconBadgeEnabled';
const String urlAutocompleteSuggestionRemovalEnabledKey =
    'urlAutocompleteSuggestionRemovalEnabled';
const String autoHideAddressBarKey = 'autoHideAddressBar';
const String navigationCacheIndexKey = 'navigationCacheIndex';
const String whatsNewSeenVersionKey = 'whatsNewSeenVersion';

// Firebase configuration keys
const String firebaseApiKeyPref = 'firebase_FIREBASE_API_KEY';
const String firebaseAppIdPref = 'firebase_FIREBASE_APP_ID';
const String firebaseSenderIdPref = 'firebase_FIREBASE_MESSAGING_SENDER_ID';
const String firebaseProjectIdPref = 'firebase_FIREBASE_PROJECT_ID';
const String firebaseStorageBucketPref = 'firebase_FIREBASE_STORAGE_BUCKET';

const String defaultHomepageUrl = 'about:browser-home';

const _integrationTestFlag = String.fromEnvironment('INTEGRATION_TEST');
const _integrationReportFlag =
    String.fromEnvironment('INTEGRATION_TEST_SHOULD_REPORT_RESULTS_TO_NATIVE');

bool get isIntegrationTest =>
    _integrationTestFlag.isNotEmpty || _integrationReportFlag.isNotEmpty;

bool _windowChromeReady = false;

bool get isWindowChromeReady => _windowChromeReady;

void markWindowChromeReady() {
  _windowChromeReady = true;
}
