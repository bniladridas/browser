// SPDX-License-Identifier: MIT
//
// Copyright 2026 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:passkeys/types.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:file_selector/file_selector.dart';
import 'package:desktop_drop/desktop_drop.dart';

import '../constants.dart';
import '../features/theme_color_parser.dart';
import '../features/theme_utils.dart';
import '../features/bookmark_manager.dart';
import '../features/firebase_config_store.dart';
import '../features/password_prompt.dart';
import '../features/password_storage.dart';
import 'clickable_icon.dart';
import '../features/connectivity_service.dart';
import '../features/password_autofill.dart';
import '../features/login_detection.dart';
import '../features/webauthn_script.dart';
import '../features/webauthn_service.dart';
import '../browser_state.dart';

import '../logging/logger.dart';
import '../logging/network_monitor.dart';
import '../utils/string_utils.dart';
import '../utils/keyboard_utils.dart';
import 'package:pkg/ai_chat_widget.dart';
import 'package:pkg/ai_service.dart';
import 'network_debug_dialog.dart';
import 'save_password_prompt.dart';
import 'password_vault_screen.dart';
import 'interaction_blocker.dart';

export '../features/theme_color_parser.dart';

const _userAgents = {
  TargetPlatform.macOS: {
    'modern':
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0.2 Safari/605.1.15',
    'legacy':
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.2 Safari/605.1.15',
  },
  TargetPlatform.windows: {
    'modern':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0',
    'legacy':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:91.0) Gecko/20100101 Firefox/91.0',
  },
  TargetPlatform.linux: {
    'modern':
        'Mozilla/5.0 (X11; Linux x86_64; rv:120.0) Gecko/20100101 Firefox/120.0',
    'legacy':
        'Mozilla/5.0 (X11; Linux x86_64; rv:91.0) Gecko/20100101 Firefox/91.0',
  },
};

String _getUserAgent(bool useLegacy) {
  final platformAgents =
      _userAgents[defaultTargetPlatform] ?? _userAgents[TargetPlatform.macOS]!;
  final agentType = useLegacy ? 'legacy' : 'modern';
  return platformAgents[agentType]!;
}

class UrlUtils {
  static String processUrl(String url) {
    if (url.startsWith('file://')) {
      return url;
    }
    if (!url.contains('://')) {
      if (url.contains(' ') ||
          (!url.contains('.') &&
              !url.contains(':') &&
              url.toLowerCase() != 'localhost')) {
        url = 'https://www.google.com/search?q=${Uri.encodeComponent(url)}';
      } else {
        url = 'https://$url';
      }
    }
    return url;
  }

  static bool isValidUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null && const {'http', 'https', 'file'}.contains(uri.scheme);
  }
}

class UrlSubmissionDecision {
  const UrlSubmissionDecision({
    required this.normalizedInput,
    required this.shouldLoadUrl,
    required this.shouldShowAiSuggestions,
  });

  final String normalizedInput;
  final bool shouldLoadUrl;
  final bool shouldShowAiSuggestions;
}

@visibleForTesting
UrlSubmissionDecision resolveUrlSubmission({
  required String submittedValue,
  required bool aiSearchSuggestionsEnabled,
}) {
  final normalized = submittedValue.trim();
  if (normalized.isEmpty) {
    return UrlSubmissionDecision(
      normalizedInput: normalized,
      shouldLoadUrl: false,
      shouldShowAiSuggestions: aiSearchSuggestionsEnabled,
    );
  }
  return UrlSubmissionDecision(
    normalizedInput: normalized,
    shouldLoadUrl: true,
    shouldShowAiSuggestions: false,
  );
}

class FaviconUrlPolicy {
  static String normalizeJsResult(dynamic result) {
    if (result == null) return '';
    if (result is String) return result.trim();
    return result.toString().trim();
  }

  static String unescapeWrappedJson(String raw) {
    var text = raw.trim();
    if (text.length >= 2 &&
        ((text.startsWith('"') && text.endsWith('"')) ||
            (text.startsWith("'") && text.endsWith("'")))) {
      text = text.substring(1, text.length - 1);
    }
    return text
        .replaceAll(r'\"', '"')
        .replaceAll(r"\'", "'")
        .replaceAll(r'\\', '\\');
  }

  static String? resolveFaviconFromJsResult(dynamic result) {
    final raw = normalizeJsResult(result);
    if (raw.isEmpty) return null;
    var normalized = raw;
    final unescaped = unescapeWrappedJson(raw).trim();
    if (unescaped.isNotEmpty) {
      normalized = unescaped;
    }
    normalized = normalized.replaceAll(r'\/', '/').trim();
    final lower = normalized.toLowerCase();
    if (lower == 'null' || lower == 'undefined' || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  static bool isLikelyRenderableFaviconUrl(String url) {
    final normalized = url.trim();
    final normalizedLower = normalized.toLowerCase();
    if (normalizedLower.isEmpty) return false;
    if (normalizedLower.contains('google.com/s2/favicons')) return true;
    if (normalizedLower.startsWith('data:')) return false;
    return normalizedLower.endsWith('.ico') ||
        normalizedLower.endsWith('.png') ||
        normalizedLower.endsWith('.jpg') ||
        normalizedLower.endsWith('.jpeg') ||
        normalizedLower.endsWith('.gif') ||
        normalizedLower.endsWith('.webp');
  }

  static bool isSafeFaviconUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.host.isEmpty) return false;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return false;
    return !_isBlockedFaviconHost(uri.host);
  }

  static Future<bool> isSafeFaviconUrlWithDns(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.host.isEmpty) return false;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return false;
    if (_isBlockedFaviconHost(uri.host)) return false;
    try {
      final addresses = await InternetAddress.lookup(uri.host);
      if (addresses.isEmpty) return false;
      for (final address in addresses) {
        if (_isBlockedAddress(address)) {
          return false;
        }
      }
      return true;
    } catch (_) {
      // Fail closed on DNS errors for SSRF-sensitive URL validation.
      return false;
    }
  }

  static bool isSafeAndRenderableFaviconUrl(String url) {
    final normalized = url.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    return isSafeFaviconUrl(normalized) &&
        isLikelyRenderableFaviconUrl(normalized);
  }

  static bool _isBlockedFaviconHost(String host) {
    final normalizedHost = host.trim().toLowerCase();
    if (normalizedHost.isEmpty) return true;
    if (normalizedHost == 'localhost' ||
        normalizedHost.endsWith('.localhost') ||
        normalizedHost.endsWith('.local')) {
      return true;
    }
    final ip = InternetAddress.tryParse(normalizedHost);
    if (ip == null) return false;
    return _isBlockedAddress(ip);
  }

  static bool _isBlockedAddress(InternetAddress ip) {
    if (ip.type == InternetAddressType.IPv4) {
      final b = ip.rawAddress;
      if (b.length != 4) return true;
      if (b[0] == 10) return true; // 10.0.0.0/8
      if (b[0] == 127) return true; // loopback
      if (b[0] == 0) return true; // invalid/unspecified
      if (b[0] == 169 && b[1] == 254) {
        return true; // link-local + metadata range
      }
      if (b[0] == 172 && b[1] >= 16 && b[1] <= 31) return true; // 172.16.0.0/12
      if (b[0] == 192 && b[1] == 168) return true; // 192.168.0.0/16
      if (b[0] == 100 && b[1] >= 64 && b[1] <= 127) return true; // CGNAT
      if (b[0] >= 224) return true; // multicast/reserved
      return false;
    }
    if (ip.type == InternetAddressType.IPv6) {
      final b = ip.rawAddress;
      if (b.length != 16) return true;
      final isUnspecified = b.every((v) => v == 0);
      if (isUnspecified) return true;
      final isLoopback = b.sublist(0, 15).every((v) => v == 0) && b[15] == 1;
      if (isLoopback) return true; // ::1
      final isIpv4Mapped = b.sublist(0, 10).every((v) => v == 0) &&
          b[10] == 0xFF &&
          b[11] == 0xFF;
      if (isIpv4Mapped) return true; // ::ffff:x.x.x.x
      if ((b[0] & 0xFE) == 0xFC) return true; // fc00::/7 unique local
      if (b[0] == 0xFE && (b[1] & 0xC0) == 0x80) {
        return true; // fe80::/10 link-local
      }
      if (b[0] == 0xFF) return true; // multicast
      return false;
    }
    return true;
  }
}

class _PageFontChoice {
  const _PageFontChoice(this.label, this.cssFamily);

  final String label;
  final String cssFamily;
}

const List<_PageFontChoice> _pageFontChoices = [
  _PageFontChoice('Default (Website)', ''),
  _PageFontChoice('Arial', 'Arial, Helvetica, sans-serif'),
  _PageFontChoice('Georgia', 'Georgia, serif'),
  _PageFontChoice('Times New Roman', '"Times New Roman", Times, serif'),
  _PageFontChoice('Verdana', 'Verdana, Geneva, sans-serif'),
  _PageFontChoice('Trebuchet MS', '"Trebuchet MS", sans-serif'),
  _PageFontChoice('Courier New', '"Courier New", Courier, monospace'),
  _PageFontChoice('Comic Sans MS', '"Comic Sans MS", cursive'),
];

class _FontPickerResult {
  const _FontPickerResult({
    required this.fontFamily,
    required this.applyToCurrentSite,
    this.clearCurrentSiteRule = false,
  });

  final String fontFamily;
  final bool applyToCurrentSite;
  final bool clearCurrentSiteRule;
}

class SettingsDialog extends HookWidget {
  const SettingsDialog({
    super.key,
    this.onSettingsChanged,
    this.onClearCaches,
    this.onThemePreviewChanged,
    this.currentTheme,
    required this.aiAvailable,
    this.aiSearchSuggestionsEnabled = false,
    this.advancedCacheEnabled = false,
  });

  final void Function()? onSettingsChanged;
  final void Function()? onClearCaches;
  final void Function(AppThemeMode mode)? onThemePreviewChanged;
  final AppThemeMode? currentTheme;
  final bool aiAvailable;
  final bool aiSearchSuggestionsEnabled;
  final bool advancedCacheEnabled;

  String _themeLabel(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return 'system';
      case AppThemeMode.light:
        return 'light';
      case AppThemeMode.dark:
        return 'dark';
      case AppThemeMode.adjust:
        return 'adjust (page)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const compactDensity = VisualDensity(horizontal: -2, vertical: -2);

    final homepage = useState<String?>(null);
    final hideAppBar = useState(false);
    final useModernUserAgent = useState(false);
    final enableGitFetch = useState(false);
    final privateBrowsing = useState(false);
    final originalPrivateBrowsing = useRef<bool?>(null);
    final adBlocking = useState(false);
    final strictMode = useState(false);
    final passwordManagerEnabled = useState(false);
    final reorderableTabs = useState(false);
    final aiSearchSuggestionsEnabled =
        useState(this.aiSearchSuggestionsEnabled);
    final advancedCacheEnabled = useState(this.advancedCacheEnabled);
    final selectedTheme =
        useState<AppThemeMode>(currentTheme ?? AppThemeMode.system);
    final homepageController = useTextEditingController();
    final settingsScrollController = useScrollController();

    final firebaseApiKey = useTextEditingController();
    final firebaseAppId = useTextEditingController();
    final firebaseSenderId = useTextEditingController();
    final firebaseProjectId = useTextEditingController();
    final firebaseStorageBucket = useTextEditingController();
    final showFirebaseConfig = useState(false);
    final loadedFirebaseConfig = useRef<Map<String, String>>(<String, String>{});

    useEffect(() {
      Future<void> loadPreferences() async {
        final prefs = await SharedPreferences.getInstance();
        final storedHomepage = prefs.getString(homepageKey);
        final resolvedHomepage =
            (storedHomepage == null || storedHomepage.isEmpty)
                ? defaultHomepageUrl
                : storedHomepage;
        hideAppBar.value = prefs.getBool(hideAppBarKey) ?? false;
        useModernUserAgent.value =
            prefs.getBool(useModernUserAgentKey) ?? false;
        enableGitFetch.value = prefs.getBool(enableGitFetchKey) ?? false;
        privateBrowsing.value = prefs.getBool(privateBrowsingKey) ?? false;
        originalPrivateBrowsing.value = privateBrowsing.value;
        adBlocking.value = prefs.getBool(adBlockingKey) ?? false;
        strictMode.value = prefs.getBool(strictModeKey) ?? false;
        passwordManagerEnabled.value =
            prefs.getBool(passwordManagerEnabledKey) ?? false;
        reorderableTabs.value = prefs.getBool(reorderableTabsKey) ?? false;
        aiSearchSuggestionsEnabled.value =
            prefs.getBool(aiSearchSuggestionsEnabledKey) ?? false;
        advancedCacheEnabled.value =
            prefs.getBool(advancedCacheEnabledKey) ?? false;
        if (prefs.getString(themeModeKey) != null) {
          selectedTheme.value = AppThemeMode.values.firstWhere(
              (m) => m.name == prefs.getString(themeModeKey),
              orElse: () => currentTheme ?? AppThemeMode.system);
        }

        final firebaseConfig = await FirebaseConfigStore.loadSettingsConfig();
        firebaseApiKey.text = firebaseConfig[firebaseApiKeyPref] ?? '';
        firebaseAppId.text = firebaseConfig[firebaseAppIdPref] ?? '';
        firebaseSenderId.text = firebaseConfig[firebaseSenderIdPref] ?? '';
        firebaseProjectId.text = firebaseConfig[firebaseProjectIdPref] ?? '';
        firebaseStorageBucket.text =
            firebaseConfig[firebaseStorageBucketPref] ?? '';
        loadedFirebaseConfig.value = <String, String>{
          firebaseApiKeyPref: firebaseApiKey.text,
          firebaseAppIdPref: firebaseAppId.text,
          firebaseSenderIdPref: firebaseSenderId.text,
          firebaseProjectIdPref: firebaseProjectId.text,
          firebaseStorageBucketPref: firebaseStorageBucket.text,
        };

        // Mark dialog ready only after all settings are loaded.
        homepage.value = resolvedHomepage;
        homepageController.text =
            resolvedHomepage == defaultHomepageUrl ? '' : resolvedHomepage;
      }

      loadPreferences();
      return null;
    }, const []);

    if (homepage.value == null) {
      return const AlertDialog(
        title: Text('Settings'),
        content: CircularProgressIndicator(),
      );
    }

    final dialogMaxHeight = math.min(
      MediaQuery.of(context).size.height * 0.72,
      560.0,
    );

    return AlertDialog(
      alignment: Alignment.centerRight,
      insetPadding: const EdgeInsets.fromLTRB(24, 24, 16, 24),
      title: Text(
        'Settings',
        style: theme.textTheme.titleSmall?.copyWith(fontSize: 15),
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: dialogMaxHeight),
        child: Scrollbar(
          controller: settingsScrollController,
          thumbVisibility: false,
          child: SingleChildScrollView(
            controller: settingsScrollController,
            child: Theme(
              data: theme.copyWith(
                splashFactory: NoSplash.splashFactory,
                highlightColor: Colors.transparent,
                hoverColor: Colors.transparent,
                inputDecorationTheme: theme.inputDecorationTheme.copyWith(
                  hoverColor: Colors.transparent,
                ),
                switchTheme: SwitchThemeData(
                  overlayColor: WidgetStateProperty.all(Colors.transparent),
                  thumbColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return theme.colorScheme.onPrimary;
                    }
                    return theme.colorScheme.outline;
                  }),
                ),
                listTileTheme: ListTileThemeData(
                  dense: true,
                  visualDensity: compactDensity,
                  titleTextStyle: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: theme.colorScheme.onSurface,
                  ),
                  subtitleTextStyle: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: homepageController,
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Homepage',
                      hintText: 'leave blank for welcome page',
                      hintStyle: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                      isDense: true,
                      filled: false,
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: SwitchListTile(
                      title: const Text('Hide App Bar'),
                      value: hideAppBar.value,
                      onChanged: (value) => hideAppBar.value = value,
                      hoverColor: Colors.transparent,
                    ),
                  ),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: SwitchListTile(
                      title: const Text('Legacy User Agent'),
                      value: useModernUserAgent.value,
                      onChanged: (value) => useModernUserAgent.value = value,
                      hoverColor: Colors.transparent,
                    ),
                  ),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: SwitchListTile(
                      title: const Text('Git Fetch'),
                      value: enableGitFetch.value,
                      onChanged: (value) => enableGitFetch.value = value,
                      hoverColor: Colors.transparent,
                    ),
                  ),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: SwitchListTile(
                      title: const Text('Private Browsing'),
                      value: privateBrowsing.value,
                      onChanged: (value) => privateBrowsing.value = value,
                      hoverColor: Colors.transparent,
                    ),
                  ),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: SwitchListTile(
                      title: const Text('Ad Blocking'),
                      value: adBlocking.value,
                      onChanged: (value) => adBlocking.value = value,
                      hoverColor: Colors.transparent,
                    ),
                  ),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: SwitchListTile(
                      title: const Text('Strict Mode'),
                      value: strictMode.value,
                      onChanged: (value) => strictMode.value = value,
                      hoverColor: Colors.transparent,
                    ),
                  ),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: SwitchListTile(
                      title: const Text('Password Manager'),
                      value: passwordManagerEnabled.value,
                      onChanged: (value) =>
                          passwordManagerEnabled.value = value,
                      hoverColor: Colors.transparent,
                    ),
                  ),
                  if (passwordManagerEnabled.value)
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: ListTile(
                        leading: const Icon(Icons.lock),
                        title: const Text('Manage Passwords'),
                        trailing: const Icon(Icons.chevron_right),
                        hoverColor: Colors.transparent,
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const PasswordVaultScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: SwitchListTile(
                      title: const Text('Reorderable Tabs'),
                      value: reorderableTabs.value,
                      onChanged: (value) => reorderableTabs.value = value,
                      hoverColor: Colors.transparent,
                    ),
                  ),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: SwitchListTile(
                      title: const Text('AI Search Suggestions'),
                      value: aiSearchSuggestionsEnabled.value,
                      onChanged: (value) =>
                          aiSearchSuggestionsEnabled.value = value,
                      hoverColor: Colors.transparent,
                    ),
                  ),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: SwitchListTile(
                      title: const Text('Advanced Cache'),
                      value: advancedCacheEnabled.value,
                      onChanged: (value) => advancedCacheEnabled.value = value,
                      hoverColor: Colors.transparent,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Theme',
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: AppThemeMode.values.map((mode) {
                      final isSelected = selectedTheme.value == mode;
                      return Theme(
                        data: theme.copyWith(
                          splashFactory: NoSplash.splashFactory,
                          highlightColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                        ),
                        child: ChoiceChip(
                          label: Text(
                            _themeLabel(mode),
                            style: theme.textTheme.bodySmall
                                ?.copyWith(fontSize: 11),
                          ),
                          selected: isSelected,
                          showCheckmark: false,
                          visualDensity: compactDensity,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          onSelected: (_) {
                            selectedTheme.value = mode;
                            onThemePreviewChanged?.call(mode);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'AI Chat',
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontSize: 12),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: aiAvailable
                                    ? theme.colorScheme.primaryContainer
                                    : theme.colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    aiAvailable
                                        ? Icons.verified_rounded
                                        : Icons.warning_amber_rounded,
                                    size: 12,
                                    color: aiAvailable
                                        ? theme.colorScheme.onPrimaryContainer
                                        : theme.colorScheme.onErrorContainer,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    aiAvailable
                                        ? 'Firebase ready'
                                        : 'Firebase missing',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: aiAvailable
                                          ? theme.colorScheme.onPrimaryContainer
                                          : theme.colorScheme.onErrorContainer,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () => showFirebaseConfig.value =
                              !showFirebaseConfig.value,
                          hoverColor: Colors.transparent,
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Row(
                              children: [
                                Icon(
                                  showFirebaseConfig.value
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  size: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Config',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 9,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (showFirebaseConfig.value) ...[
                          const SizedBox(height: 4),
                          TextField(
                            controller: firebaseApiKey,
                            obscureText: true,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontSize: 9),
                            decoration: InputDecoration(
                              labelText: 'API Key',
                              labelStyle: TextStyle(fontSize: 8),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 6),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              filled: false,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextField(
                            controller: firebaseAppId,
                            obscureText: true,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontSize: 9),
                            decoration: InputDecoration(
                              labelText: 'App ID',
                              labelStyle: TextStyle(fontSize: 8),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 6),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              filled: false,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextField(
                            controller: firebaseSenderId,
                            obscureText: true,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontSize: 9),
                            decoration: InputDecoration(
                              labelText: 'Sender ID',
                              labelStyle: TextStyle(fontSize: 8),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 6),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              filled: false,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextField(
                            controller: firebaseProjectId,
                            obscureText: true,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontSize: 9),
                            decoration: InputDecoration(
                              labelText: 'Project ID',
                              labelStyle: TextStyle(fontSize: 8),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 6),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              filled: false,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextField(
                            controller: firebaseStorageBucket,
                            obscureText: true,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontSize: 9),
                            decoration: InputDecoration(
                              labelText: 'Storage',
                              labelStyle: TextStyle(fontSize: 8),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 6),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              filled: false,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            final homepageText = homepageController.text.trim();
            String homepageToSave;
            if (homepageText.isEmpty) {
              homepageToSave = defaultHomepageUrl;
            } else {
              final processed = UrlUtils.processUrl(homepageText);
              if (!UrlUtils.isValidUrl(processed)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid homepage URL')),
                );
                return;
              }
              homepageToSave = processed;
            }
            final prefs = await SharedPreferences.getInstance();

            // Check if Firebase config changed from loaded values.
            final oldApiKey =
                loadedFirebaseConfig.value[firebaseApiKeyPref] ?? '';
            final oldAppId =
                loadedFirebaseConfig.value[firebaseAppIdPref] ?? '';
            final oldSenderId =
                loadedFirebaseConfig.value[firebaseSenderIdPref] ?? '';
            final oldProjectId =
                loadedFirebaseConfig.value[firebaseProjectIdPref] ?? '';
            final oldStorageBucket =
                loadedFirebaseConfig.value[firebaseStorageBucketPref] ?? '';

            final newApiKey = firebaseApiKey.text.trim();
            final newAppId = firebaseAppId.text.trim();
            final newSenderId = firebaseSenderId.text.trim();
            final newProjectId = firebaseProjectId.text.trim();
            final newStorageBucket = firebaseStorageBucket.text.trim();

            final firebaseChanged = oldApiKey != newApiKey ||
                oldAppId != newAppId ||
                oldSenderId != newSenderId ||
                oldProjectId != newProjectId ||
                oldStorageBucket != newStorageBucket;

            await prefs.setString(homepageKey, homepageToSave);
            await prefs.setBool(hideAppBarKey, hideAppBar.value);
            await prefs.setBool(
                useModernUserAgentKey, useModernUserAgent.value);
            await prefs.setBool(enableGitFetchKey, enableGitFetch.value);
            await prefs.setBool(privateBrowsingKey, privateBrowsing.value);
            await prefs.setBool(adBlockingKey, adBlocking.value);
            await prefs.setBool(strictModeKey, strictMode.value);
            await prefs.setBool(
                passwordManagerEnabledKey, passwordManagerEnabled.value);
            await prefs.setBool(reorderableTabsKey, reorderableTabs.value);
            await prefs.setBool(aiSearchSuggestionsEnabledKey,
                aiSearchSuggestionsEnabled.value);
            await prefs.setBool(
                advancedCacheEnabledKey, advancedCacheEnabled.value);
            await prefs.setString(themeModeKey, selectedTheme.value.name);

            try {
              await FirebaseConfigStore.saveSettingsConfig(
                apiKey: newApiKey,
                appId: newAppId,
                senderId: newSenderId,
                projectId: newProjectId,
                storageBucket: newStorageBucket,
              );
            } catch (_) {
              // Keep settings save flow resilient even when secure storage fails.
            }

            onSettingsChanged?.call();
            if (privateBrowsing.value &&
                originalPrivateBrowsing.value == false) {
              onClearCaches?.call();
            }

            final message = firebaseChanged
                ? 'Settings saved — restart required for Firebase changes'
                : 'Settings saved';

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message)),
            );
            Navigator.of(context).pop(true);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class FocusUrlIntent extends Intent {}

class RefreshIntent extends Intent {}

class GoBackIntent extends Intent {}

class GoForwardIntent extends Intent {}

class NewTabIntent extends Intent {}

class CloseTabIntent extends Intent {}

class NewWindowIntent extends Intent {}

class PageFontIntent extends Intent {}

class TabData {
  String currentUrl;
  final TextEditingController urlController;
  final FocusNode urlFocusNode;
  final TextEditingController torrySearchController;
  final FocusNode torrySearchFocusNode;
  WebViewController? webViewController;
  BrowserState state = const BrowserState.idle();
  final List<String> history = [];
  bool isClosed = false;
  String? lastErrorMessage;
  DateTime? lastErrorAt;
  Brightness? detectedBrightness;
  Color? detectedSeedColor;
  SavePasswordPromptData? pendingPasswordPrompt;
  String? faviconUrl;
  String? forwardUrl; // URL to go forward to when on home page
  bool hideStaleWebViewUntilPageFinish = false;

  TabData(this.currentUrl, {String? displayUrl})
      : urlController = TextEditingController(text: displayUrl ?? currentUrl),
        urlFocusNode = FocusNode(),
        torrySearchController = TextEditingController(),
        torrySearchFocusNode = FocusNode();
}

class _ThemeTone {
  final Brightness brightness;
  final Color? seedColor;

  const _ThemeTone({required this.brightness, this.seedColor});
}

Future<Map<String, dynamic>> _fetchGitHubRepo(String url) async {
  final stopwatch = Stopwatch()..start();
  try {
    final response =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
    NetworkMonitor().logRequest(
      url: url,
      method: 'GET',
      statusCode: response.statusCode,
      duration: stopwatch.elapsed,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load repo: ${response.statusCode}');
    }
  } catch (e) {
    NetworkMonitor().onRequestFailed(
      url: url,
      method: 'GET',
      error: e is Exception ? e : Exception(e.toString()),
      duration: stopwatch.elapsed,
    );
    rethrow;
  }
}

class GitFetchDialog extends HookWidget {
  const GitFetchDialog({super.key, required this.onOpenInNewTab});

  final void Function(String url) onOpenInNewTab;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repoController = useTextEditingController();
    final isLoading = useState(false);
    final repoData = useState<Map<String, dynamic>?>(null);
    final errorMessage = useState<String?>(null);
    final isDisposed = useRef(false);

    useEffect(() {
      return () {
        isDisposed.value = true;
      };
    }, []);

    Future<void> fetchRepo() async {
      final repo = repoController.text.trim();
      if (repo.isEmpty) return;

      final parts = repo.split('/');
      if (parts.length != 2) {
        if (!isDisposed.value) {
          errorMessage.value = 'Invalid format. Use owner/repo';
        }
        return;
      }

      if (!isDisposed.value) {
        isLoading.value = true;
        errorMessage.value = null;
        repoData.value = null;
      }

      try {
        final url = 'https://api.github.com/repos/${parts[0]}/${parts[1]}';
        final response = await _fetchGitHubRepo(url);
        if (!isDisposed.value) {
          isLoading.value = false;
          repoData.value = response;
        }
      } catch (e) {
        if (!isDisposed.value) {
          isLoading.value = false;
          errorMessage.value = 'Failed to fetch repo: $e';
        }
      }
    }

    return AlertDialog(
      title: Text(
        'Git Fetch',
        style: theme.textTheme.titleSmall?.copyWith(fontSize: 15),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: repoController,
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
              decoration: InputDecoration(
                labelText: 'GitHub Repo (owner/repo)',
                hintText: 'e.g., flutter/flutter',
                isDense: true,
                filled: false,
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (isLoading.value)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            if (errorMessage.value != null)
              Text(
                errorMessage.value!,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: theme.colorScheme.error,
                ),
              ),
            if (repoData.value != null) ...[
              const SizedBox(height: 8),
              Text(
                'Name: ${repoData.value!['name'] ?? 'N/A'}',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
              ),
              Text(
                'Description: ${repoData.value!['description'] ?? 'No description'}',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Stars: ${repoData.value!['stargazers_count'] ?? 0}',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
              ),
              Text(
                'Forks: ${repoData.value!['forks_count'] ?? 0}',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
              ),
              Text(
                'Language: ${repoData.value!['language'] ?? 'N/A'}',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
              ),
              Text(
                'Open Issues: ${repoData.value!['open_issues_count'] ?? 0}',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: fetchRepo,
          child: const Text('Fetch'),
        ),
        if (repoData.value != null)
          TextButton(
            onPressed: () {
              final url = 'https://github.com/${repoController.text}';
              onOpenInNewTab(url);
              Navigator.of(context).pop();
            },
            child: const Text('Open in New Tab'),
          ),
      ],
    );
  }
}

class BrowserPage extends StatefulWidget {
  const BrowserPage(
      {super.key,
      required this.initialUrl,
      this.hideAppBar = false,
      this.useModernUserAgent = false,
      this.enableGitFetch = false,
      this.privateBrowsing = false,
      this.adBlocking = false,
      this.strictMode = false,
      this.pageFontFamily = '',
      this.aiSearchSuggestionsEnabled = false,
      this.advancedCacheEnabled = false,
      this.themeMode = AppThemeMode.system,
      this.aiAvailable = true,
      this.onSettingsChanged,
      this.onPageThemeChanged,
      this.onThemePreviewChanged,
      this.onThemePreviewReset,
      this.onShowWhatsNew});

  final String initialUrl;
  final bool hideAppBar;
  final bool useModernUserAgent;
  final bool enableGitFetch;
  final bool privateBrowsing;
  final bool adBlocking;
  final bool strictMode;
  final String pageFontFamily;
  final bool aiSearchSuggestionsEnabled;
  final bool advancedCacheEnabled;
  final AppThemeMode themeMode;
  final bool aiAvailable;
  final void Function()? onSettingsChanged;
  final void Function(ThemeMode mode, Color? seedColor)? onPageThemeChanged;
  final void Function(AppThemeMode mode)? onThemePreviewChanged;
  final void Function()? onThemePreviewReset;
  final Future<void> Function()? onShowWhatsNew;

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class KeepAliveWrapper extends StatefulWidget {
  final Widget child;

  const KeepAliveWrapper({super.key, required this.child});

  @override
  State<KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _BrowserPageState extends State<BrowserPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // WebKit cancellation signal seen on Apple platforms.
  static const int _wkErrorCancelled = -999;
  // Chromium aborted navigation code (net::ERR_ABORTED). On Android WebView
  // this may represent real failures (e.g. unsupported auth scheme), so we do
  // not blanket-ignore it.
  static const int _chromiumErrorAborted = -3;

  static const Set<String> _allowedNavigationSchemes = {
    'http',
    'https',
    'about',
    'blob',
    'data',
    'file',
  };

  late TabController tabController;
  final List<TabData> tabs = [];
  final bookmarkManager = BookmarkManager();
  late int previousTabIndex;
  List<RegExp> adBlockerPatterns = [];
  bool _isOnline = true;
  final ConnectivityService _connectivityService = ConnectivityService();
  StreamSubscription<bool>? _connectivitySubscription;
  late AnimationController _refreshIconController;
  final Set<String> _downloadableExtensions = {
    'dmg',
    'zip',
    'tar',
    'gz',
    'tgz',
    'bz2',
    'xz',
    '7z',
    'rar',
    'exe',
    'msi',
    'pkg',
    'deb',
    'rpm',
    'apk',
    'iso',
    'pdf',
    'csv',
    'json',
    'xml',
    'mp3',
    'mp4',
    'm4a',
    'mov',
    'avi',
    'mkv',
  };
  final Set<String> _pendingHeaderChecks = {};
  bool _dragging = false;
  final FocusNode _keyboardFocusNode = FocusNode();
  bool _reorderableTabs = false;
  String _pageFontFamily = '';
  final Map<String, String> _siteFontFamilies = {};
  final List<String> _history = [];
  static const int _maxHistoryEntries = 200;
  static const int _maxTabHistoryEntries = 50;
  static const int _maxNavigationCacheEntries = 200;
  static const int _navigationCachePrewarmCount = 8;
  static const Duration _navigationCachePrewarmTimeout = Duration(seconds: 3);
  static const double _kMacOsLeadingInsetWithTrafficLights = 16.0;
  static const double _kMacOsAddressBarLeftOffset = 60.0;
  static const double _kDefaultLeadingInset = 16.0;
  static const double _kMacOsTopToolbarInset = 8.0;
  static const String _legacyLayoutFixScriptAsset =
      'assets/legacy_layout_fix.js';
  static const String _disablePagePointerEventsScript = '''
(() => {
  try {
    const blockerId = '__browserPointerBlockerStyle';
    if (!document.getElementById(blockerId)) {
      const style = document.createElement('style');
      style.id = blockerId;
      style.textContent = 'html, body, body * { pointer-events: none !important; }';
      document.documentElement.appendChild(style);
    }
  } catch (_) {}
})();
''';
  static const String _restorePagePointerEventsScript = '''
(() => {
  try {
    document.getElementById('__browserPointerBlockerStyle')?.remove();
  } catch (_) {}
})();
''';
  AiService? _aiService;
  List<String>? _cachedAiSearchSuggestions;
  DateTime? _lastAiSuggestionFetchAt;
  final Map<String, int> _navigationCacheIndex = {};
  final MenuController _overflowMenuController = MenuController();
  Timer? _overflowMenuCloseTimer;
  bool _isOverflowTriggerHovered = false;
  bool _isOverflowMenuHovered = false;
  bool _overflowMenuOpen = false;
  bool _urlAutocompleteOpen = false;
  bool _modalInteractionBlockOpen = false;
  bool _windowButtonsSyncRetryQueued = false;
  Timer? _windowButtonsSyncRetryTimer;
  final Map<String, String> _faviconCacheByHost = {};
  final Map<String, bool> _faviconHostSafetyCache = {};
  String? _legacyLayoutFixScript;

  static const String _themeProbeScript = '''
(() => {
  const isTransparent = (color) => {
    if (!color) return true;
    const normalized = color.toLowerCase().replace(/\\s+/g, '');
    return normalized === 'transparent' || normalized === 'rgba(0,0,0,0)';
  };
  const getBg = (el) => {
    if (!el) return null;
    const style = window.getComputedStyle(el);
    return style ? style.backgroundColor : null;
  };
  const normalizeColor = (raw) => {
    if (!raw || typeof raw !== 'string') return null;
    const candidate = raw.trim();
    if (!candidate) return null;
    const probe = document.createElement('div');
    probe.style.color = '';
    probe.style.color = candidate;
    if (!probe.style.color) return null;
    return probe.style.color;
  };
  const getEffectiveBg = (el) => {
    let current = el;
    let depth = 0;
    while (current && depth < 20) {
      const color = getBg(current);
      if (color && !isTransparent(color)) return color;
      current = current.parentElement;
      depth += 1;
    }
    return null;
  };
  const centerEl = document.elementFromPoint(
    window.innerWidth / 2,
    window.innerHeight / 2
  );
  const sampleBg = getEffectiveBg(centerEl);
  const bg = getEffectiveBg(document.documentElement) ||
    getEffectiveBg(document.body) || null;
  const themeColorMeta = Array.from(
    document.querySelectorAll('meta[name="theme-color"]')
  );
  const preferredThemeColor = themeColorMeta.find((meta) => {
    const media = meta.getAttribute('media');
    if (!media) return true;
    return window.matchMedia ? window.matchMedia(media).matches : false;
  }) || themeColorMeta[0] || null;
  const themeColor = normalizeColor(preferredThemeColor
    ?.getAttribute('content') || null);
  const metaColorScheme = document.querySelector('meta[name="color-scheme"]')
    ?.getAttribute('content') || null;
  const colorScheme = window.getComputedStyle(document.documentElement)
    .colorScheme || null;
  const textColor = window.getComputedStyle(document.body || document.documentElement)
    .color || null;
  const accentHintEl = document.querySelector(
    'header, nav, [role="banner"], [class*="header"], [class*="navbar"]'
  ) || document.querySelector(
    'a, button, [role="button"], [class*="btn"], [class*="link"]'
  );
  const accentHint = accentHintEl
    ? (getEffectiveBg(accentHintEl) ||
      window.getComputedStyle(accentHintEl).color || null)
    : null;
  const prefersDark = window.matchMedia &&
    window.matchMedia('(prefers-color-scheme: dark)').matches;
  return JSON.stringify({
    bg,
    sampleBg,
    themeColor,
    accentHint,
    metaColorScheme,
    colorScheme,
    textColor,
    prefersDark
  });
})()
''';

  String _displayUrl(String url) => url == defaultHomepageUrl ? '' : url;

  Future<void> _syncMacWindowButtonsVisibility({bool allowRetry = true}) async {
    if (defaultTargetPlatform != TargetPlatform.macOS || isIntegrationTest) {
      return;
    }
    if (!isWindowChromeReady) {
      if (allowRetry && !_windowButtonsSyncRetryQueued) {
        _windowButtonsSyncRetryQueued = true;
        _windowButtonsSyncRetryTimer?.cancel();
        _windowButtonsSyncRetryTimer =
            Timer.periodic(const Duration(milliseconds: 120), (timer) {
          if (!mounted) {
            _windowButtonsSyncRetryQueued = false;
            _windowButtonsSyncRetryTimer = null;
            timer.cancel();
            return;
          }
          if (!isWindowChromeReady) return;
          _windowButtonsSyncRetryQueued = false;
          _windowButtonsSyncRetryTimer = null;
          timer.cancel();
          _syncMacWindowButtonsVisibility(allowRetry: false);
        });
      }
      return;
    }
    _windowButtonsSyncRetryTimer?.cancel();
    _windowButtonsSyncRetryTimer = null;
    _windowButtonsSyncRetryQueued = false;
    try {
      await windowManager.setTitleBarStyle(
        TitleBarStyle.hidden,
        windowButtonVisibility: !widget.hideAppBar,
      );
    } catch (e) {
      logger.w('Failed to update macOS window button visibility: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncMacWindowButtonsVisibility();
    });
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _refreshIconController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _pageFontFamily = widget.pageFontFamily;
    _loadReorderableTabs();
    _loadFontOverrides();
    _loadNavigationCacheIndex();
    tabs.add(_createTab(widget.initialUrl));
    tabController = TabController(length: 1, vsync: this);
    previousTabIndex = 0;
    tabController.addListener(_onTabChanged);
    _loadBookmarks();
    _loadHistory();
    if (widget.adBlocking) {
      loadAdBlockers();
    }
    if (widget.aiAvailable && !isIntegrationTest) {
      _aiService = AiService();
    }
    _initConnectivity();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    // Check if ANY text input is focused (including dialog fields)
    final primaryFocus = FocusManager.instance.primaryFocus;
    final isTextInputFocused = primaryFocus != null &&
        primaryFocus.context != null &&
        primaryFocus.context!.widget is EditableText;

    // Check tab switching first (more specific: Cmd+Option+Arrow)
    if (KeyboardUtils.isPreviousTabKey(event)) {
      if (tabController.index > 0) {
        tabController.animateTo(tabController.index - 1);
      }
      return true;
    } else if (KeyboardUtils.isNextTabKey(event)) {
      if (tabController.index < tabs.length - 1) {
        tabController.animateTo(tabController.index + 1);
      }
      return true;
    }

    // Then check back/forward (Cmd+[ and Cmd+])
    if (!isTextInputFocused && KeyboardUtils.isBackKey(event)) {
      _goBack();
      return true;
    } else if (!isTextInputFocused && KeyboardUtils.isForwardKey(event)) {
      _goForward();
      return true;
    }

    if (KeyboardUtils.isNewTabKey(event)) {
      _addNewTab();
      return true;
    } else if (KeyboardUtils.isCloseTabKey(event)) {
      _closeTab(tabController.index);
      return true;
    } else if (KeyboardUtils.isFontPickerKey(event)) {
      _showFontPicker();
      return true;
    } else if (KeyboardUtils.isFocusUrlKey(event)) {
      activeTab.urlFocusNode.requestFocus();
      return true;
    } else if (KeyboardUtils.isEscapeKey(event)) {
      // Check if URL bar is focused
      if (activeTab.urlFocusNode.hasFocus) {
        // Close autocomplete first to avoid overlay disposal issues
        if (_urlAutocompleteOpen) {
          _setUrlAutocompleteOpen(false);
        }
        activeTab.urlFocusNode.unfocus();
        return true;
      }
      // For other text inputs in dialogs, unfocus but let event fall through
      if (isTextInputFocused) {
        FocusScope.of(context).unfocus();
        // Return false to allow dialog dismissal
        return false;
      }
      // Exit fullscreen on Esc
      _exitFullscreenIfNeeded();
      return false;
    }

    // Window-level shortcuts should work even when text input is focused
    if (KeyboardUtils.isFullscreenKey(event)) {
      _toggleFullscreen();
      return true;
    } else if (KeyboardUtils.isMinimizeKey(event)) {
      windowManager.minimize();
      return true;
    }

    if (isTextInputFocused) return false;

    if (KeyboardUtils.isRefreshKey(event)) {
      _refresh();
      return true;
    }

    return false;
  }

  Future<void> _toggleFullscreen() async {
    final isFullscreen = await windowManager.isFullScreen();
    await windowManager.setFullScreen(!isFullscreen);
  }

  Future<void> _exitFullscreenIfNeeded() async {
    final isFullscreen = await windowManager.isFullScreen();
    if (isFullscreen) {
      await windowManager.setFullScreen(false);
    }
  }

  bool _isValidHistoryUrl(String url) {
    try {
      final uri = Uri.parse(url);
      // Only allow http, https, and about schemes
      if (uri.scheme != 'http' && uri.scheme != 'https' && uri.scheme != 'about') {
        return false;
      }
      // Reject URLs with suspicious patterns
      if (url.contains('file://') || url.contains('javascript:')) {
        return false;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  void _initConnectivity() async {
    _isOnline = await _connectivityService.checkConnectivity();
    if (mounted) {
      setState(() {}); // Update UI with initial state
    }

    _connectivitySubscription =
        _connectivityService.onConnectivityChanged.listen((isOnline) {
      if (mounted && _isOnline != isOnline) {
        setState(() {
          _isOnline = isOnline;
        });
      }
    });
  }

  TabData _createTab(String initialUrl) {
    final tab = TabData(initialUrl, displayUrl: _displayUrl(initialUrl));
    tab.urlFocusNode.addListener(() => _onUrlFocusChanged(tab));
    return tab;
  }

  void _onUrlFocusChanged(TabData tab) {
    if (!mounted || tab.isClosed) return;
    if (!tab.urlFocusNode.hasFocus && _urlAutocompleteOpen) {
      _setUrlAutocompleteOpen(false);
    }
    _syncPagePointerEvents(tab);
  }

  void _setUrlAutocompleteOpen(bool open) {
    if (_urlAutocompleteOpen == open) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _urlAutocompleteOpen == open) return;
      setState(() => _urlAutocompleteOpen = open);
      _syncPointerEventsForAllTabs();
    });
  }

  void _setModalInteractionBlockOpen(bool open) {
    if (_modalInteractionBlockOpen == open) return;
    _modalInteractionBlockOpen = open;
    _syncPointerEventsForAllTabs();
  }

  void _setOverflowMenuOpen(bool open) {
    if (_overflowMenuOpen == open) return;
    _overflowMenuOpen = open;
    _syncPointerEventsForAllTabs();
  }

  void _syncPointerEventsForAllTabs() {
    for (final tab in tabs) {
      _syncPagePointerEvents(tab);
    }
  }

  Future<T?> _showWithModalInteractionBlock<T>(
      Future<T?> Function() showModal) async {
    _setModalInteractionBlockOpen(true);
    try {
      return await showModal();
    } finally {
      _setModalInteractionBlockOpen(false);
    }
  }

  void _syncPagePointerEvents(TabData tab) {
    if (tab.isClosed) return;
    final shouldBlock = identical(tab, activeTab) &&
        (_urlAutocompleteOpen || _modalInteractionBlockOpen || _overflowMenuOpen);
    unawaited(_setTabPointerEventsEnabled(tab, !shouldBlock));
  }

  Future<void> _setTabPointerEventsEnabled(TabData tab, bool enabled) async {
    final controller = tab.webViewController;
    if (controller == null || tab.isClosed) return;
    final script = enabled
        ? _restorePagePointerEventsScript
        : _disablePagePointerEventsScript;
    try {
      await controller.runJavaScript(script);
    } catch (_) {
      // Best effort only.
    }
  }

  @override
  void didUpdateWidget(covariant BrowserPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hideAppBar != widget.hideAppBar) {
      _syncMacWindowButtonsVisibility();
    }
    if (oldWidget.pageFontFamily != widget.pageFontFamily) {
      _pageFontFamily = widget.pageFontFamily;
      _applyFontOverrideToAllTabs();
    }
    if (oldWidget.advancedCacheEnabled != widget.advancedCacheEnabled &&
        widget.advancedCacheEnabled) {
      _prewarmNavigationCache();
    }
    if (oldWidget.useModernUserAgent != widget.useModernUserAgent) {
      _applyUserAgentToAllTabs();
    }
    if (oldWidget.themeMode != widget.themeMode) {
      if (widget.themeMode == AppThemeMode.adjust) {
        _applyThemeForTab(activeTab);
      } else {
        widget.onPageThemeChanged?.call(ThemeMode.system, null);
      }
    }
  }

  Future<void> _applyUserAgentToAllTabs() async {
    final userAgent = _getUserAgent(widget.useModernUserAgent);
    for (final tab in tabs) {
      final controller = tab.webViewController;
      if (controller == null) continue;
      try {
        await controller.setUserAgent(userAgent);
        await controller.reload();
      } on PlatformException catch (e, s) {
        if (!_isMissingPluginException(e)) {
          logger.w('Unexpected PlatformException on user-agent update',
              error: e, stackTrace: s);
        }
      }
    }
  }

  Future<void> _loadInitialRequestForTab(TabData tab) async {
    final controller = tab.webViewController;
    if (controller == null) return;
    try {
      await controller.setUserAgent(_getUserAgent(widget.useModernUserAgent));
    } on PlatformException catch (e, s) {
      if (!_isMissingPluginException(e)) {
        logger.w('Unexpected PlatformException on setUserAgent',
            error: e, stackTrace: s);
      }
    }

    try {
      await controller.loadRequest(Uri.parse(tab.currentUrl));
    } on FormatException {
      logger.w('Invalid URL: ${tab.currentUrl}');
      _handleLoadError(tab, 'Invalid URL format');
    } on PlatformException catch (e, s) {
      if (!_isMissingPluginException(e)) {
        logger.w('Unexpected PlatformException on initial loadRequest',
            error: e, stackTrace: s);
      }
    }
  }

  bool _isMissingPluginException(PlatformException e) {
    return e.code == 'MissingPluginException';
  }

  void _applyThemeForTab(TabData tab) {
    if (widget.themeMode != AppThemeMode.adjust) return;
    if (tab.currentUrl == defaultHomepageUrl || tab.state is BrowserError) {
      widget.onPageThemeChanged?.call(ThemeMode.system, null);
      return;
    }
    if (tab.detectedBrightness != null) {
      widget.onPageThemeChanged?.call(
        tab.detectedBrightness == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light,
        tab.detectedSeedColor,
      );
      return;
    }
    _updateThemeFromTab(tab);
  }

  Future<void> _updateThemeFromTab(TabData tab) async {
    if (widget.themeMode != AppThemeMode.adjust) return;
    if (widget.strictMode) {
      widget.onPageThemeChanged?.call(ThemeMode.system, null);
      return;
    }
    final controller = tab.webViewController;
    if (controller == null) return;
    try {
      final result =
          await controller.runJavaScriptReturningResult(_themeProbeScript);
      final probe = _parseThemeProbe(result);
      final tone = probe == null ? null : _toneFromProbe(probe);
      if (tone != null) {
        tab.detectedBrightness = tone.brightness;
        tab.detectedSeedColor = tone.seedColor;
        widget.onPageThemeChanged?.call(
          tone.brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
          tone.seedColor,
        );
      } else {
        tab.detectedBrightness = null;
        tab.detectedSeedColor = null;
        widget.onPageThemeChanged?.call(ThemeMode.system, null);
      }
    } catch (_) {
      tab.detectedBrightness = null;
      tab.detectedSeedColor = null;
      widget.onPageThemeChanged?.call(ThemeMode.system, null);
    }
  }

  Future<void> _applyFontOverride(TabData tab) async {
    if (widget.strictMode) return;
    final controller = tab.webViewController;
    if (controller == null) return;
    final normalizedFont = _resolveFontForTab(tab).trim();
    try {
      if (normalizedFont.isEmpty) {
        await controller.runJavaScript('''
(() => {
  const style = document.getElementById('browser-font-override-style');
  if (style) {
    style.remove();
  }
})();
''');
        return;
      }
      final fontFamilyJson = jsonEncode(normalizedFont);
      await controller.runJavaScript('''
(() => {
  const fontFamily = $fontFamilyJson;
  const styleId = 'browser-font-override-style';
  let style = document.getElementById(styleId);
  if (!style) {
    style = document.createElement('style');
    style.id = styleId;
    (document.head || document.documentElement).appendChild(style);
  }
  style.textContent =
    'html, body, body * { font-family: ' + fontFamily + ' !important; }';
})();
''');
    } catch (e, s) {
      logger.w('Failed to apply page font override', error: e, stackTrace: s);
    }
  }

  Future<String?> _loadLegacyLayoutFixScript() async {
    if (_legacyLayoutFixScript != null) {
      return _legacyLayoutFixScript;
    }
    try {
      _legacyLayoutFixScript =
          await rootBundle.loadString(_legacyLayoutFixScriptAsset);
      return _legacyLayoutFixScript;
    } catch (e, s) {
      logger.w('Failed to load legacy layout fix script',
          error: e, stackTrace: s);
      return null;
    }
  }

  Future<void> _applyLegacyLayoutFix(TabData tab) async {
    if (!widget.useModernUserAgent || widget.strictMode) return;
    final controller = tab.webViewController;
    if (controller == null) return;
    final script = await _loadLegacyLayoutFixScript();
    if (script == null || script.trim().isEmpty) return;
    try {
      await controller.runJavaScript(script);
    } catch (e, s) {
      logger.w('Failed to apply legacy layout fix', error: e, stackTrace: s);
    }
  }

  Future<void> _applyFontOverrideToAllTabs() async {
    for (final tab in tabs) {
      await _applyFontOverride(tab);
    }
  }

  String? _hostFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return null;
    return uri.host.toLowerCase();
  }

  String _resolveFontForTab(TabData tab) {
    final host = _hostFromUrl(tab.currentUrl);
    if (host != null && _siteFontFamilies.containsKey(host)) {
      return _siteFontFamilies[host] ?? '';
    }
    return _pageFontFamily;
  }

  Future<void> _loadFontOverrides() async {
    final prefs = await SharedPreferences.getInstance();
    final rawOverrides = prefs.getString(pageFontOverridesKey);
    if (rawOverrides == null || rawOverrides.trim().isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(rawOverrides);
      if (decoded is! Map<String, dynamic>) return;
      _siteFontFamilies
        ..clear()
        ..addEntries(
          decoded.entries.where((entry) => entry.key.trim().isNotEmpty).map(
              (entry) => MapEntry(entry.key.toLowerCase(), '${entry.value}')),
        );
      await _applyFontOverrideToAllTabs();
    } catch (e, s) {
      logger.w('Failed to load font overrides', error: e, stackTrace: s);
    }
  }

  Future<void> _persistFontOverrides() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(pageFontOverridesKey, jsonEncode(_siteFontFamilies));
  }

  Map<String, dynamic>? _parseThemeProbe(dynamic result) {
    if (result is Map<String, dynamic>) return result;
    final raw = _normalizeJsResult(result);
    if (raw.isEmpty) return null;
    final decoded = _tryDecodeProbe(raw);
    if (decoded != null) return decoded;
    final unescaped = _unescapeWrappedJson(raw);
    if (unescaped != raw) {
      final decodedUnescaped = _tryDecodeProbe(unescaped);
      if (decodedUnescaped != null) return decodedUnescaped;
    }
    return null;
  }

  Map<String, dynamic>? _tryDecodeProbe(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is String) {
        final nested = jsonDecode(decoded);
        if (nested is Map<String, dynamic>) return nested;
      }
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  String _normalizeJsResult(dynamic result) {
    return FaviconUrlPolicy.normalizeJsResult(result);
  }

  String _unescapeWrappedJson(String raw) {
    return FaviconUrlPolicy.unescapeWrappedJson(raw);
  }

  _ThemeTone? _toneFromProbe(Map<String, dynamic> probe) {
    final tone = resolveThemeProbeDecision(probe);
    if (tone == null) return null;
    return _ThemeTone(brightness: tone.brightness, seedColor: tone.seedColor);
  }

  Future<void> loadAdBlockers() async {
    try {
      final jsonString = await rootBundle.loadString('assets/ad_blockers.json');
      final List<dynamic> rules = jsonDecode(jsonString);
      adBlockerPatterns =
          rules.map((rule) => RegExp(rule['urlFilter'])).toList();
    } catch (e) {
      logger.w('Failed to load or compile ad blockers: $e');
    }
  }

  void _onTabChanged() {
    previousTabIndex = tabController.index;
    _syncPointerEventsForAllTabs();
    _applyThemeForTab(tabs[tabController.index]);
    if (mounted) {
      setState(() {});
    }
  }

  TabData get activeTab => tabs[tabController.index];

  Future<void> _handlePasswordPromptAction(SavePasswordAction action) async {
    final promptData = activeTab.pendingPasswordPrompt;
    if (promptData == null) return;

    setState(() {
      activeTab.pendingPasswordPrompt = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final policy = SitePasswordPolicy(prefs: prefs);

    switch (action) {
      case SavePasswordAction.save:
        final repository = PasswordStorageRepository();
        final credential = PasswordCredential.create(
          origin: promptData.origin,
          username: promptData.username,
          password: promptData.password,
        );
        await repository.saveCredential(credential);
        break;
      case SavePasswordAction.neverForSite:
        await policy.setNeverSave(promptData.origin);
        break;
      case SavePasswordAction.notNow:
        // Do nothing, just dismiss
        break;
    }
  }

  Future<void> _attemptAutofill(TabData tab) async {
    if (widget.privateBrowsing) return;

    final prefs = await SharedPreferences.getInstance();
    final passwordManagerEnabled =
        prefs.getBool(passwordManagerEnabledKey) ?? false;
    if (!passwordManagerEnabled) return;

    try {
      // Get actual URL from WebView controller, not tab.currentUrl (can be spoofed)
      if (tab.webViewController == null || tab.isClosed) return;
      final actualUrl = await tab.webViewController!.currentUrl();
      if (actualUrl == null) return;

      final autofillService = PasswordAutofillService();
      final matches = await autofillService.getMatchingCredentials(actualUrl);

      if (matches.isEmpty) return;

      // Use the most recently updated credential
      final credential = matches.first;
      final script = autofillService.generateAutofillScript(
        credential.username,
        credential.password,
      );

      await tab.webViewController!.runJavaScript(script);
    } catch (e, s) {
      logger.w('Failed to autofill credentials', error: e, stackTrace: s);
    }
  }

  Future<void> _handleWebAuthnMessage(TabData tab, String message) async {
    String? type;
    int? requestId;
    try {
      // Check if it's a status message (not JSON)
      if (!message.startsWith('{')) {
        logger.i('WebAuthn status: $message');
        return;
      }

      final data = jsonDecode(message) as Map<String, dynamic>;
      type = data['type'] as String;
      requestId = data['requestId'] as int;
      final options = data['options'] as Map<String, dynamic>;

      logger.i('WebAuthn request: $type (ID: $requestId)');

      final webAuthnService = WebAuthnService();

      if (type == 'create') {
        await _handleWebAuthnCreate(tab, requestId, options, webAuthnService);
      } else if (type == 'get') {
        await _handleWebAuthnGet(tab, requestId, options, webAuthnService);
      } else {
        // Unknown type - reject to prevent hanging
        throw Exception('Unknown WebAuthn request type: $type');
      }
    } catch (e, s) {
      logger.e('Failed to handle WebAuthn message', error: e, stackTrace: s);

      if (requestId != null && tab.webViewController != null) {
        final errorMsg = jsonEncode(e.toString());
        await tab.webViewController!.runJavaScript('''
          if (window.resolveWebAuthnRequest) {
            window.resolveWebAuthnRequest($requestId, false, $errorMsg);
          }
        ''');
      }
    }
  }

  Future<void> _handleWebAuthnCreate(
    TabData tab,
    int requestId,
    Map<String, dynamic> options,
    WebAuthnService service,
  ) async {
    try {
      // Validate RP ID against page origin
      final pageUrl = await tab.webViewController?.currentUrl();
      if (pageUrl == null) {
        throw Exception('Cannot determine page origin');
      }
      final pageOrigin = Uri.parse(pageUrl);
      final rpId = options['rp']['id'] as String;

      if (!_isValidRpId(rpId, pageOrigin.host)) {
        throw Exception(
            'RP ID validation failed: $rpId does not match origin ${pageOrigin.host}');
      }

      final challenge = _base64UrlEncode(List<int>.from(options['challenge']));
      final rp = options['rp'] as Map<String, dynamic>;
      final user = options['user'] as Map<String, dynamic>;
      final userId = _base64UrlEncode(List<int>.from(user['id']));

      final request = RegisterRequestType(
        challenge: challenge,
        relyingParty: RelyingPartyType(
          name: rp['name'] as String,
          id: rp['id'] as String,
        ),
        user: UserType(
          name: user['name'] as String,
          id: userId,
          displayName: user['displayName'] as String,
        ),
        excludeCredentials: const [],
      );

      final response = await service.register(request);

      if (response != null && tab.webViewController != null) {
        // Decode base64url strings to bytes
        final rawIdBytes = base64Url.decode(response.rawId.padRight(
            response.rawId.length + (4 - response.rawId.length % 4) % 4, '='));
        final clientDataBytes = base64Url.decode(response.clientDataJSON
            .padRight(
                response.clientDataJSON.length +
                    (4 - response.clientDataJSON.length % 4) % 4,
                '='));
        final attestationBytes = base64Url.decode(response.attestationObject
            .padRight(
                response.attestationObject.length +
                    (4 - response.attestationObject.length % 4) % 4,
                '='));

        final jsResponse = '''
          {
            id: '${response.id}',
            rawId: new Uint8Array([${rawIdBytes.join(',')}]),
            response: {
              clientDataJSON: new Uint8Array([${clientDataBytes.join(',')}]),
              attestationObject: new Uint8Array([${attestationBytes.join(',')}])
            },
            type: 'public-key'
          }
        ''';

        await tab.webViewController!.runJavaScript('''
          if (window.resolveWebAuthnRequest) {
            window.resolveWebAuthnRequest($requestId, true, $jsResponse);
          }
        ''');
      } else {
        await _rejectWebAuthnRequest(
            tab, requestId, 'User cancelled or error occurred');
      }
    } catch (e, s) {
      logger.e('WebAuthn create failed', error: e, stackTrace: s);
      await _rejectWebAuthnRequest(tab, requestId, e.toString());
    }
  }

  Future<void> _handleWebAuthnGet(
    TabData tab,
    int requestId,
    Map<String, dynamic> options,
    WebAuthnService service,
  ) async {
    try {
      // Validate RP ID against page origin
      final pageUrl = await tab.webViewController?.currentUrl();
      if (pageUrl == null) {
        throw Exception('Cannot determine page origin');
      }
      final pageOrigin = Uri.parse(pageUrl);
      final rpId = options['rpId'] as String;

      if (!_isValidRpId(rpId, pageOrigin.host)) {
        throw Exception(
            'RP ID validation failed: $rpId does not match origin ${pageOrigin.host}');
      }

      final challenge = _base64UrlEncode(List<int>.from(options['challenge']));

      final allowCredentials = options['allowCredentials'] as List<dynamic>?;
      final credentials = allowCredentials?.map((c) {
        final id = List<int>.from(c['id']);
        return CredentialType(
          id: _base64UrlEncode(id),
          type: c['type'] as String? ?? 'public-key',
          transports: const [],
        );
      }).toList();

      final request = AuthenticateRequestType(
        challenge: challenge,
        relyingPartyId: rpId,
        mediation: MediationType.Optional,
        preferImmediatelyAvailableCredentials: true,
        allowCredentials: credentials,
      );

      final response = await service.authenticate(request);

      if (response != null && tab.webViewController != null) {
        // Decode base64url strings to bytes
        final rawIdBytes = base64Url.decode(response.rawId.padRight(
            response.rawId.length + (4 - response.rawId.length % 4) % 4, '='));
        final clientDataBytes = base64Url.decode(response.clientDataJSON
            .padRight(
                response.clientDataJSON.length +
                    (4 - response.clientDataJSON.length % 4) % 4,
                '='));
        final authDataBytes = base64Url.decode(response.authenticatorData
            .padRight(
                response.authenticatorData.length +
                    (4 - response.authenticatorData.length % 4) % 4,
                '='));
        final signatureBytes = base64Url.decode(response.signature.padRight(
            response.signature.length + (4 - response.signature.length % 4) % 4,
            '='));

        final userHandleBytes = response.userHandle.isNotEmpty
            ? base64Url.decode(response.userHandle.padRight(
                response.userHandle.length +
                    (4 - response.userHandle.length % 4) % 4,
                '='))
            : null;

        final jsResponse = '''
          {
            id: '${response.id}',
            rawId: new Uint8Array([${rawIdBytes.join(',')}]),
            response: {
              clientDataJSON: new Uint8Array([${clientDataBytes.join(',')}]),
              authenticatorData: new Uint8Array([${authDataBytes.join(',')}]),
              signature: new Uint8Array([${signatureBytes.join(',')}]),
              userHandle: ${userHandleBytes != null ? "new Uint8Array([${userHandleBytes.join(',')}])" : 'null'}
            },
            type: 'public-key'
          }
        ''';

        await tab.webViewController!.runJavaScript('''
          if (window.resolveWebAuthnRequest) {
            window.resolveWebAuthnRequest($requestId, true, $jsResponse);
          }
        ''');
      } else {
        await _rejectWebAuthnRequest(
            tab, requestId, 'User cancelled or error occurred');
      }
    } catch (e, s) {
      logger.e('WebAuthn get failed', error: e, stackTrace: s);
      await _rejectWebAuthnRequest(tab, requestId, e.toString());
    }
  }

  Future<void> _rejectWebAuthnRequest(
      TabData tab, int requestId, String error) async {
    if (tab.webViewController == null) return;

    final errorMsg = jsonEncode(error);
    await tab.webViewController!.runJavaScript('''
      if (window.resolveWebAuthnRequest) {
        window.resolveWebAuthnRequest($requestId, false, $errorMsg);
      }
    ''');
  }

  String _base64UrlEncode(List<int> bytes) {
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  bool _isAllowedNavigationUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return _allowedNavigationSchemes.contains(uri.scheme.toLowerCase());
  }

  bool _isValidRpId(String rpId, String originHost) {
    // RP ID must be exactly the origin host or a registrable domain suffix
    if (rpId == originHost) {
      return true;
    }

    // Check if rpId is a valid suffix of originHost
    if (originHost.endsWith('.$rpId')) {
      // Prevent public suffix attacks (basic check)
      final parts = rpId.split('.');
      if (parts.length >= 2) {
        return true;
      }
    }

    return false;
  }

  String _sanitizeUrlForLog(String? rawUrl) {
    if (rawUrl == null || rawUrl.isEmpty) {
      return '';
    }
    try {
      final uri = Uri.parse(rawUrl);
      final hasQuery = uri.hasQuery;
      final hasFragment = uri.fragment.isNotEmpty;
      if (!hasQuery && !hasFragment) {
        return rawUrl;
      }
      return uri
          .replace(
            query: hasQuery ? '<REDACTED>' : null,
            fragment: hasFragment ? '<REDACTED>' : null,
          )
          .toString();
    } catch (_) {
      var sanitized = rawUrl;
      final queryIndex = sanitized.indexOf('?');
      if (queryIndex != -1) {
        sanitized = '${sanitized.substring(0, queryIndex)}?<REDACTED>';
      }
      final fragmentIndex = sanitized.indexOf('#');
      if (fragmentIndex != -1) {
        sanitized = '${sanitized.substring(0, fragmentIndex)}#<REDACTED>';
      }
      return sanitized;
    }
  }

  void _logBlockedNavigation(TabData tab, String requestedUrl) {
    final currentTabIndex = tabs.indexOf(tab);
    logger.w(jsonEncode({
      'event': 'blocked_scheme',
      'requested_url': _sanitizeUrlForLog(requestedUrl),
      'current_url': _sanitizeUrlForLog(tab.currentUrl),
      'tab_index': currentTabIndex,
      'timestamp': DateTime.now().toIso8601String(),
    }));
  }

  bool _shouldIgnoreWebResourceError(WebResourceError error) {
    // Subresource failures should not replace the full page with an error view.
    if (error.isForMainFrame == false) {
      return true;
    }
    if (error.errorCode == _wkErrorCancelled) {
      return true;
    }
    if (error.errorCode == _chromiumErrorAborted) {
      return false;
    }
    final description = error.description.toLowerCase();
    return description.contains('cancelled') ||
        description.contains('canceled') ||
        description.contains('interrupted');
  }

  bool _isDownloadUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.pathSegments.isEmpty) {
      return false;
    }
    final lastSegment = uri.pathSegments.last;
    final dotIndex = lastSegment.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == lastSegment.length - 1) {
      return false;
    }
    final extension = lastSegment.substring(dotIndex + 1).toLowerCase();
    return _downloadableExtensions.contains(extension);
  }

  String _fileNameFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.pathSegments.isEmpty) {
      return 'download';
    }
    final lastSegment = uri.pathSegments.last;
    final decoded = Uri.decodeComponent(lastSegment);
    return decoded.isEmpty ? 'download' : decoded;
  }

  bool _looksLikeBinaryContentType(String? contentType) {
    if (contentType == null) return false;
    final lower = contentType.toLowerCase();
    if (lower.startsWith('text/')) return false;
    if (lower.contains('application/json')) return false;
    if (lower.contains('application/xml')) return false;
    if (lower.contains('application/xhtml+xml')) return false;
    return lower.contains('application') ||
        lower.contains('audio') ||
        lower.contains('video') ||
        lower.contains('image');
  }

  bool _isAttachmentHeader(String? contentDisposition) {
    if (contentDisposition == null) return false;
    final lower = contentDisposition.toLowerCase();
    return lower.contains('attachment') || lower.contains('filename=');
  }

  Future<bool> _hasDownloadHeaders(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final stopwatch = Stopwatch()..start();
    try {
      final head = await http.head(uri);
      NetworkMonitor().logRequest(
        url: url,
        method: 'HEAD',
        statusCode: head.statusCode,
        duration: stopwatch.elapsed,
      );
      if (_isAttachmentHeader(head.headers['content-disposition']) ||
          _looksLikeBinaryContentType(head.headers['content-type'])) {
        return true;
      }
      if (head.statusCode != 405 && head.statusCode != 403) {
        return false;
      }
    } catch (e) {
      NetworkMonitor().onRequestFailed(
        url: url,
        method: 'HEAD',
        error: e is Exception ? e : Exception(e.toString()),
        duration: stopwatch.elapsed,
      );
    }

    try {
      final client = http.Client();
      final stopwatch = Stopwatch()..start();
      try {
        final request = http.Request('GET', uri);
        request.headers['Range'] = 'bytes=0-0';
        final response = await client.send(request);
        NetworkMonitor().logRequest(
          url: url,
          method: 'GET',
          statusCode: response.statusCode,
          duration: stopwatch.elapsed,
        );
        final isDownload =
            _isAttachmentHeader(response.headers['content-disposition']) ||
                _looksLikeBinaryContentType(response.headers['content-type']);
        await response.stream.drain();
        return isDownload;
      } finally {
        client.close();
      }
    } catch (e) {
      NetworkMonitor().onRequestFailed(
        url: url,
        method: 'GET',
        error: e is Exception ? e : Exception(e.toString()),
        duration: Duration.zero,
      );
      return false;
    }
  }

  Future<void> _maybeDownloadByHeaders(String url) async {
    if (_pendingHeaderChecks.contains(url)) return;
    _pendingHeaderChecks.add(url);
    try {
      final shouldDownload = await _hasDownloadHeaders(url);
      if (shouldDownload) {
        await _downloadFile(url);
      }
    } finally {
      _pendingHeaderChecks.remove(url);
    }
  }

  Future<void> _downloadFile(String url) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(content: Text('Downloading...')),
    );

    try {
      final fileName = _fileNameFromUrl(url);
      final saveLocation = await getSaveLocation(suggestedName: fileName);
      if (!mounted) return;
      if (saveLocation == null) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          const SnackBar(content: Text('Download canceled')),
        );
        return;
      }
      final filePath = saveLocation.path;
      final stopwatch = Stopwatch()..start();
      final response = await http.get(Uri.parse(url));
      NetworkMonitor().logRequest(
        url: url,
        method: 'GET',
        statusCode: response.statusCode,
        duration: stopwatch.elapsed,
      );
      if (!mounted) return;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        if (!mounted) return;
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(content: Text('Saved to Downloads: $fileName')),
        );
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    }
  }

  void _addNewTab() {
    if (mounted) {
      setState(() {
        tabs.add(_createTab(widget.initialUrl));
        tabController
            .dispose(); // Dispose the old controller to prevent memory leaks.
        tabController = TabController(
            length: tabs.length, vsync: this, initialIndex: tabs.length - 1);
        tabController.addListener(_onTabChanged);
      });
      previousTabIndex = tabController.index;
    }
  }

  void _closeTab(int index) {
    if (tabs.length > 1) {
      setState(() {
        tabs[index].isClosed = true;
        tabs[index].urlController.dispose();
        tabs[index].urlFocusNode.dispose();
        tabs[index].torrySearchController.dispose();
        tabs[index].torrySearchFocusNode.dispose();
        tabs.removeAt(index);

        // Clear cache and cookies for private browsing
        if (widget.privateBrowsing) {
          _clearAllCaches();
        }

        // Determine the new index before disposing the old controller.
        int newIndex = tabController.index;
        if (newIndex >= tabs.length) {
          newIndex = tabs.length - 1;
        }

        // Dispose the old controller and create a new one.
        tabController.dispose();
        tabController = TabController(
            length: tabs.length, vsync: this, initialIndex: newIndex);
        tabController.addListener(_onTabChanged);
      });
      previousTabIndex = tabController.index;
    }
  }

  void _reorderTab(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final currentIndex = tabController.index;
      final tab = tabs.removeAt(oldIndex);
      tabs.insert(newIndex, tab);

      // Update controller index
      if (currentIndex == oldIndex) {
        tabController.index = newIndex;
      } else if (currentIndex > oldIndex && currentIndex <= newIndex) {
        tabController.index = currentIndex - 1;
      } else if (currentIndex < oldIndex && currentIndex >= newIndex) {
        tabController.index = currentIndex + 1;
      }
    });
  }

  Widget _buildTabItem(TabData tab, int index, bool isSelected,
      {bool showDragHandle = false}) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showDragHandle) ...[
          Icon(
            Icons.drag_indicator,
            size: 16,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 4),
        ],
        _buildTabFavicon(tab, theme),
        const SizedBox(width: 6),
        Text(
          (Uri.tryParse(tab.currentUrl)?.host ?? tab.currentUrl).truncate(14),
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        if (tabs.length > 1) ...[
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _closeTab(index),
            child: Icon(
              Icons.close,
              size: 15,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTabFavicon(TabData tab, ThemeData theme) {
    final fallback = Icon(
      Icons.public,
      size: 15,
      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
    );
    final faviconUrl = tab.faviconUrl;
    if (faviconUrl == null || faviconUrl.trim().isEmpty) {
      return fallback;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Image.network(
        faviconUrl,
        width: 15,
        height: 15,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }

  String? _defaultFaviconUrlFor(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return Uri.https(
      'www.google.com',
      '/s2/favicons',
      <String, String>{
        'domain': uri.host,
        'sz': '64',
      },
    ).toString();
  }

  Future<bool> _isSafeFaviconUrl(String url) async {
    final normalized = url.trim();
    final uri = Uri.tryParse(normalized);
    final host = uri?.host.toLowerCase() ?? '';
    if (host.isNotEmpty) {
      final cached = _faviconHostSafetyCache[host];
      if (cached == false) return false;
    }
    final safe = await FaviconUrlPolicy.isSafeFaviconUrlWithDns(normalized);
    if (host.isNotEmpty && !safe) {
      _faviconHostSafetyCache[host] = false;
    }
    return safe;
  }

  Future<bool> _isSafeAndRenderableFaviconUrl(String url) async {
    final normalized = url.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    if (!FaviconUrlPolicy.isLikelyRenderableFaviconUrl(normalized)) {
      return false;
    }
    return _isSafeFaviconUrl(normalized);
  }

  Future<void> _updateTabFavicon(TabData tab) async {
    final controller = tab.webViewController;
    if (controller == null || tab.isClosed) return;
    final host = _hostFromUrl(tab.currentUrl);
    if (host != null) {
      final cached = _faviconCacheByHost[host];
      if (cached != null && cached.isNotEmpty) {
        if (cached != tab.faviconUrl && mounted && !tab.isClosed) {
          setState(() {
            tab.faviconUrl = cached;
          });
        }
        return;
      }
    }

    String? resolvedFavicon;
    try {
      final result = await controller.runJavaScriptReturningResult('''
(() => {
  const toAbs = (href) => {
    try { return new URL(href, window.location.href).href; } catch (_) { return null; }
  };
  const relScore = (rel) => {
    if (rel === 'icon' || rel === 'shortcut icon') return 0; // Primary favicon rel
    if (rel.includes('apple-touch-icon')) return 1; // High-quality fallback icon
    if (rel.includes('icon')) return 2; // Other icon rel variants
    return 9; // Lowest priority / unknown rel
  };
  const extScore = (href) => {
    const h = href.toLowerCase();
    if (h.endsWith('.ico')) return 0; // Best compatibility for favicon rendering
    if (h.endsWith('.png')) return 1; // Preferred raster fallback
    if (h.endsWith('.jpg') || h.endsWith('.jpeg')) return 2; // Acceptable raster fallback
    if (h.endsWith('.gif') || h.endsWith('.webp')) return 3; // Lower priority raster types
    if (h.endsWith('.svg')) return 9; // Lowest priority (often not renderable in tab favicon path)
    return 4; // Unknown extension
  };

  const links = Array.from(document.querySelectorAll('link[rel][href]'));
  const candidates = links
    .map((link) => {
      const rel = (link.getAttribute('rel') || '').toLowerCase().trim();
      const href = (link.getAttribute('href') || '').trim();
      if (!href || href.startsWith('data:')) return null;
      if (rel.includes('mask-icon')) return null;
      if (!rel.includes('icon')) return null;
      const abs = toAbs(href);
      if (!abs) return null;
      return { abs, rel, relOrder: relScore(rel), extOrder: extScore(abs) };
    })
    .filter(Boolean)
    .sort((a, b) => {
      if (a.relOrder !== b.relOrder) return a.relOrder - b.relOrder;
      return a.extOrder - b.extOrder;
    });

  if (candidates.length > 0) return candidates[0].abs;
  return null;
})();
''');
      resolvedFavicon = FaviconUrlPolicy.resolveFaviconFromJsResult(result);
    } catch (_) {
      // Best effort only.
    }
    resolvedFavicon ??= _defaultFaviconUrlFor(tab.currentUrl);
    final isResolvedFaviconSafeAndRenderable =
        resolvedFavicon != null && resolvedFavicon.isNotEmpty
            ? await _isSafeAndRenderableFaviconUrl(resolvedFavicon)
            : false;
    if (resolvedFavicon != null &&
        resolvedFavicon.isNotEmpty &&
        !isResolvedFaviconSafeAndRenderable) {
      // Keep current working favicon when page reports non-renderable icons.
      resolvedFavicon = tab.faviconUrl ?? _defaultFaviconUrlFor(tab.currentUrl);
    }
    final isResolvedFaviconSafe =
        resolvedFavicon != null && resolvedFavicon.isNotEmpty
            ? await _isSafeFaviconUrl(resolvedFavicon)
            : false;
    if (resolvedFavicon != null &&
        resolvedFavicon.isNotEmpty &&
        isResolvedFaviconSafe &&
        host != null &&
        host.isNotEmpty) {
      _faviconCacheByHost[host] = resolvedFavicon;
    }
    if (resolvedFavicon == null || resolvedFavicon.isEmpty) return;
    if (resolvedFavicon == tab.faviconUrl || !mounted || tab.isClosed) return;
    setState(() {
      tab.faviconUrl = resolvedFavicon;
    });
  }

  Future<void> _loadReorderableTabs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _reorderableTabs = prefs.getBool(reorderableTabsKey) ?? false;
    });
  }

  Future<void> _setWindowMovable(bool movable) async {
    if (isIntegrationTest) return;
    try {
      await windowManager.setMovable(movable);
    } catch (e) {
      logger.w('Failed to update window movability: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _saveBookmarks();
      _saveHistory();
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _connectivitySubscription?.cancel();
    _refreshIconController.dispose();
    _overflowMenuCloseTimer?.cancel();
    _windowButtonsSyncRetryTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _keyboardFocusNode.dispose();
    for (final tab in tabs) {
      tab.urlController.dispose();
      tab.urlFocusNode.dispose();
      tab.torrySearchController.dispose();
      tab.torrySearchFocusNode.dispose();
    }
    tabController.dispose();
    _saveBookmarks();
    _saveHistory();
    super.dispose();
  }

  void _cancelOverflowMenuClose() {
    _overflowMenuCloseTimer?.cancel();
    _overflowMenuCloseTimer = null;
  }

  void _scheduleOverflowMenuClose() {
    if (isIntegrationTest) {
      return;
    }
    _cancelOverflowMenuClose();
    _overflowMenuCloseTimer = Timer(const Duration(milliseconds: 140), () {
      if (!mounted) return;
      if (_isOverflowTriggerHovered || _isOverflowMenuHovered) return;
      _overflowMenuController.close();
    });
  }

  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarksJson = prefs.getString(bookmarksStorageKey);
    if (bookmarksJson != null) {
      try {
        bookmarkManager.load(bookmarksJson);
      } catch (e, s) {
        logger.w('Failed to load bookmarks', error: e, stackTrace: s);
        await prefs.remove(bookmarksStorageKey);
      }
    }
  }

  Future<void> _saveBookmarks() async {
    if (widget.privateBrowsing) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(bookmarksStorageKey, bookmarkManager.save());
  }

  Future<void> _loadHistory() async {
    if (widget.privateBrowsing) return;
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(browsingHistoryKey);
    if (historyJson == null || historyJson.trim().isEmpty) {
      return;
    }
    try {
      final decoded = jsonDecode(historyJson);
      if (decoded is! List) return;
      _history
        ..clear()
        ..addAll(decoded.whereType<String>());
      if (_history.length > _maxHistoryEntries) {
        _history.removeRange(0, _history.length - _maxHistoryEntries);
      }
    } catch (e, s) {
      logger.w('Failed to load browsing history', error: e, stackTrace: s);
    }
    if (widget.advancedCacheEnabled) {
      _prewarmNavigationCache();
    }
  }

  Future<void> _saveHistory() async {
    if (widget.privateBrowsing) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(browsingHistoryKey, jsonEncode(_history));
  }

  void _recordHistory(TabData tab, String url) {
    if (widget.privateBrowsing || url.isEmpty) return;

    if (tab.history.isEmpty || tab.history.last != url) {
      tab.history.add(url);
      if (tab.history.length > _maxTabHistoryEntries) {
        tab.history.removeAt(0);
      }
    }

    if (_history.isEmpty || _history.last != url) {
      _history.add(url);
      if (_history.length > _maxHistoryEntries) {
        _history.removeAt(0);
      }
      _saveHistory();
    }

    if (widget.advancedCacheEnabled) {
      _recordNavigationCache(url);
    }
  }

  Future<void> _loadNavigationCacheIndex() async {
    if (widget.privateBrowsing) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(navigationCacheIndexKey);
    if (raw == null || raw.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      _navigationCacheIndex
        ..clear()
        ..addEntries(
          decoded.entries.where((entry) => entry.key.trim().isNotEmpty).map(
              (entry) => MapEntry(entry.key, (entry.value as num).toInt())),
        );
      if (widget.advancedCacheEnabled) {
        _prewarmNavigationCache();
      }
    } catch (e, s) {
      logger.w('Failed to load navigation cache index',
          error: e, stackTrace: s);
    }
  }

  Future<void> _saveNavigationCacheIndex() async {
    if (widget.privateBrowsing) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      navigationCacheIndexKey,
      jsonEncode(_navigationCacheIndex),
    );
  }

  void _recordNavigationCache(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) return;
    _navigationCacheIndex[url] = DateTime.now().millisecondsSinceEpoch;
    if (_navigationCacheIndex.length > _maxNavigationCacheEntries) {
      final oldest = _navigationCacheIndex.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      final overflow =
          _navigationCacheIndex.length - _maxNavigationCacheEntries;
      for (var i = 0; i < overflow; i++) {
        _navigationCacheIndex.remove(oldest[i].key);
      }
    }
    _saveNavigationCacheIndex();
  }

  Future<void> _prewarmNavigationCache() async {
    if (!widget.advancedCacheEnabled || widget.privateBrowsing) return;
    final recent = _navigationCacheIndex.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final targets = recent
        .map((e) => e.key)
        .where((url) {
          final uri = Uri.tryParse(url);
          return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
        })
        .take(_navigationCachePrewarmCount)
        .toList();
    for (final url in targets) {
      try {
        final uri = Uri.parse(url);
        await http.head(uri, headers: {
          'User-Agent': _getUserAgent(widget.useModernUserAgent)
        }).timeout(_navigationCachePrewarmTimeout);
      } catch (e) {
        // Best effort prewarm only.
        logger.d('Failed to prewarm navigation cache for $url', error: e);
      }
    }
  }

  void _handleLoadError(TabData tab, String newErrorMessage) {
    final now = DateTime.now();
    final isDuplicate = tab.lastErrorMessage == newErrorMessage &&
        tab.lastErrorAt != null &&
        now.difference(tab.lastErrorAt!).inMilliseconds < 1500;
    if (!isDuplicate) {
      if (newErrorMessage.startsWith('HTTP 404')) {
        quietLogger.w('Web view load error: $newErrorMessage');
      } else {
        logger.e('Web view load error: $newErrorMessage');
      }
      tab.lastErrorMessage = newErrorMessage;
      tab.lastErrorAt = now;
    }
    if (mounted) {
      setState(() {
        tab.state = BrowserState.error(newErrorMessage);
      });
    }
    if (widget.themeMode == AppThemeMode.adjust && tab == activeTab) {
      widget.onPageThemeChanged?.call(ThemeMode.system, null);
    }
  }

  void _addBookmark() async {
    if (widget.privateBrowsing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Bookmarks are not saved in private browsing mode')),
      );
      return;
    }
    String category = 'General';
    final theme = Theme.of(context);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Add Bookmark',
          style: theme.textTheme.titleSmall?.copyWith(fontSize: 15),
        ),
        content: TextField(
          style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
          onChanged: (value) => category = value.isEmpty ? 'General' : value,
          decoration: InputDecoration(
            labelText: 'Category',
            isDense: true,
            filled: false,
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              bookmarkManager.add(activeTab.currentUrl, category);
              _saveBookmarks();
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _goBack() async {
    try {
      if (await activeTab.webViewController?.canGoBack() ?? false) {
        await activeTab.webViewController?.goBack();
        activeTab.forwardUrl =
            null; // Clear forward URL when using WebView history
      } else {
        // If can't go back, show the home page and save current URL for forward
        if (mounted) {
          setState(() {
            // Only save forward URL if we're not already on home page
            if (activeTab.currentUrl != widget.initialUrl) {
              activeTab.forwardUrl = activeTab.currentUrl;
            }
            activeTab.currentUrl = widget.initialUrl;
            final homeDisplayUrl = _displayUrl(widget.initialUrl);
            activeTab.urlController.value = TextEditingValue(
              text: homeDisplayUrl,
              selection: TextSelection.collapsed(
                offset: homeDisplayUrl.length,
              ),
            );
            activeTab.faviconUrl = _defaultFaviconUrlFor(widget.initialUrl);
            activeTab.webViewController = null;
            activeTab.hideStaleWebViewUntilPageFinish = false;
            activeTab.state = BrowserState.success(widget.initialUrl);
          });
        }
      }
    } on PlatformException catch (e, s) {
      if (!_isMissingPluginException(e)) {
        logger.w('Unexpected PlatformException on goBack',
            error: e, stackTrace: s);
      }
    }
  }

  Future<void> _goForward() async {
    try {
      // If on home page and have a forward URL, load it
      if (activeTab.currentUrl == widget.initialUrl &&
          activeTab.forwardUrl != null) {
        _loadUrl(activeTab.forwardUrl!);
        activeTab.forwardUrl = null;
      } else if (await activeTab.webViewController?.canGoForward() ?? false) {
        await activeTab.webViewController?.goForward();
      }
    } on PlatformException catch (e, s) {
      if (!_isMissingPluginException(e)) {
        logger.w('Unexpected PlatformException on goForward',
            error: e, stackTrace: s);
      }
    }
  }

  Future<void> _refresh() async {
    _refreshIconController.forward(from: 0.0);
    if (activeTab.currentUrl == defaultHomepageUrl) {
      if (mounted) {
        setState(() {
          final homeDisplayUrl = _displayUrl(defaultHomepageUrl);
          activeTab.urlController.value = TextEditingValue(
            text: homeDisplayUrl,
            selection: TextSelection.collapsed(
              offset: homeDisplayUrl.length,
            ),
          );
          activeTab.state = BrowserState.success(defaultHomepageUrl);
        });
      }
      return;
    }
    try {
      await activeTab.webViewController?.reload();
    } on PlatformException catch (e, s) {
      if (!_isMissingPluginException(e)) {
        logger.w('Unexpected PlatformException on reload',
            error: e, stackTrace: s);
      }
    }
  }

  void _showBookmarks() async {
    if (widget.privateBrowsing) {
      await _showWithModalInteractionBlock<void>(
        () => showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Bookmarks'),
            content: const Text(
                'Bookmarks are not accessible in private browsing mode'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      );
      return;
    }
    await _showWithModalInteractionBlock<void>(
      () => showDialog(
        context: context,
        builder: (context) {
          final theme = Theme.of(context);
          final dialogTheme = theme.copyWith(
            splashFactory: NoSplash.splashFactory,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
          );
          return Theme(
            data: dialogTheme,
            child: AlertDialog(
              title: Text(
                'Bookmarks',
                style: theme.textTheme.titleSmall?.copyWith(fontSize: 15),
              ),
              content: StatefulBuilder(
                builder: (context, innerSetState) => bookmarkManager
                        .bookmarks.isEmpty
                    ? const Text('No bookmarks')
                    : SizedBox(
                        width: double.maxFinite,
                        height: 300,
                        child: ListView(
                          children: bookmarkManager.bookmarks.entries
                              .map((entry) => ExpansionTile(
                                    tilePadding:
                                        const EdgeInsets.symmetric(horizontal: 8),
                                    title: Text(
                                      entry.key,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(fontSize: 13),
                                    ),
                                  children: entry.value
                                      .map((url) => ListTile(
                                            dense: true,
                                            visualDensity:
                                                const VisualDensity(
                                                    horizontal: -2,
                                                    vertical: -2),
                                            title: Text(
                                              url,
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(fontSize: 12),
                                            ),
                                            hoverColor: Colors.transparent,
                                            onTap: () {
                                              Navigator.of(context).pop();
                                              _loadUrl(url);
                                            },
                                            trailing: MouseRegion(
                                              cursor: SystemMouseCursors.click,
                                              child: GestureDetector(
                                                onTap: () async {
                                                  final confirm =
                                                      await showDialog<bool>(
                                                    context: context,
                                                    builder: (context) =>
                                                        AlertDialog(
                                                      title: const Text(
                                                          'Delete Bookmark?'),
                                                      content: Text(
                                                          'Remove "$url" from ${entry.key}?'),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.of(
                                                                      context)
                                                                  .pop(false),
                                                          child: const Text(
                                                              'Cancel'),
                                                        ),
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.of(
                                                                      context)
                                                                  .pop(true),
                                                          child: const Text(
                                                              'Delete'),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                  if (confirm == true) {
                                                    innerSetState(() {
                                                      bookmarkManager.remove(
                                                          url, entry.key);
                                                    });
                                                    _saveBookmarks();
                                                  }
                                                },
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.all(8),
                                                  child: Icon(Icons.delete,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant),
                                                ),
                                              ),
                                            ),
                                          ))
                                      .toList(),
                                ))
                            .toList(),
                      ),
                    ),
            ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      bookmarkManager.clear();
                    });
                    _saveBookmarks();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Clear All'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _clearAllCaches() async {
    try {
      final cookieManager = WebViewCookieManager();
      await cookieManager.clearCookies();
      for (final tab in tabs) {
        await tab.webViewController?.clearCache();
        await tab.webViewController
            ?.runJavaScript('localStorage.clear(); sessionStorage.clear();');
      }
      _navigationCacheIndex.clear();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(navigationCacheIndexKey);
    } catch (e, s) {
      logger.w('Failed to clear caches', error: e, stackTrace: s);
    }
  }

  void _showSettings() async {
    final saved = await _showWithModalInteractionBlock<bool>(
      () => showGeneralDialog<bool>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Settings',
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, animation, secondaryAnimation) {
          return Align(
            alignment: Alignment.centerRight,
            child: Material(
              type: MaterialType.transparency,
              child: SettingsDialog(
                onSettingsChanged: () {
                  _loadReorderableTabs();
                  widget.onSettingsChanged?.call();
                },
                onClearCaches: _clearAllCaches,
                onThemePreviewChanged: widget.onThemePreviewChanged,
                currentTheme: widget.themeMode,
                aiSearchSuggestionsEnabled: widget.aiSearchSuggestionsEnabled,
                advancedCacheEnabled: widget.advancedCacheEnabled,
                aiAvailable: widget.aiAvailable,
              ),
            ),
          );
        },
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            )),
            child: child,
          );
        },
      ),
    );
    if (saved != true) {
      widget.onThemePreviewReset?.call();
    }
  }

  Future<void> _showFontPicker() async {
    const customOptionValue = '__custom__';
    final noHoverOverlay = WidgetStateProperty.resolveWith<Color?>((states) {
      return states.contains(WidgetState.hovered) ? Colors.transparent : null;
    });
    final currentHost = _hostFromUrl(activeTab.currentUrl);
    final hasSiteRule =
        currentHost != null && _siteFontFamilies.containsKey(currentHost);
    var applyToCurrentSite = hasSiteRule;
    final initialFont =
        hasSiteRule ? _siteFontFamilies[currentHost] ?? '' : _pageFontFamily;
    final hasPreset = _pageFontChoices.any(
      (choice) => choice.cssFamily == initialFont,
    );
    var selectedValue = hasPreset ? initialFont : customOptionValue;
    final customFontController = TextEditingController(
      text: hasPreset ? '' : initialFont,
    );

    final result = await _showWithModalInteractionBlock<_FontPickerResult>(
      () => showGeneralDialog<_FontPickerResult>(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'Page Font',
        barrierColor: Colors.transparent,
        pageBuilder: (context, _, __) {
          final dialogTheme = Theme.of(context).copyWith(
            splashFactory: NoSplash.splashFactory,
            highlightColor: Colors.transparent,
          );
          return Material(
            type: MaterialType.transparency,
            child: Stack(
              children: [
                const InteractionBlocker(),
                Align(
                  alignment: Alignment.center,
                  child: Theme(
                    data: dialogTheme,
                    child: StatefulBuilder(
                      builder: (context, setStateDialog) => AlertDialog(
                        title: const Text('Page Font'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (currentHost != null) ...[
                              SizedBox(
                                width: double.infinity,
                                child: SegmentedButton<bool>(
                                  segments: [
                                    const ButtonSegment<bool>(
                                      value: false,
                                      label: Text('Global'),
                                    ),
                                    ButtonSegment<bool>(
                                      value: true,
                                      label: Text(currentHost),
                                    ),
                                  ],
                                  selected: {applyToCurrentSite},
                                  style: ButtonStyle(
                                      overlayColor: noHoverOverlay),
                                  onSelectionChanged: (selection) {
                                    setStateDialog(() {
                                      applyToCurrentSite = selection.first;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            SizedBox(
                              width: double.infinity,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 220),
                                child: SingleChildScrollView(
                                  child: Column(
                                    children: [
                                      ..._pageFontChoices.map(
                                        (choice) => ListTile(
                                          dense: true,
                                          visualDensity: const VisualDensity(
                                              horizontal: -2,
                                              vertical: -2),
                                          hoverColor: Colors.transparent,
                                          title: Text(choice.label),
                                          trailing: selectedValue ==
                                                  choice.cssFamily
                                              ? const Icon(Icons.check,
                                                  size: 18)
                                              : null,
                                          onTap: () {
                                            setStateDialog(() {
                                              selectedValue = choice.cssFamily;
                                            });
                                          },
                                        ),
                                      ),
                                      ListTile(
                                        dense: true,
                                        visualDensity: const VisualDensity(
                                            horizontal: -2, vertical: -2),
                                        hoverColor: Colors.transparent,
                                        title:
                                            const Text('Custom CSS Font Family'),
                                        trailing:
                                            selectedValue == customOptionValue
                                                ? const Icon(Icons.check,
                                                    size: 18)
                                                : null,
                                        onTap: () {
                                          setStateDialog(() {
                                            selectedValue = customOptionValue;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (selectedValue == customOptionValue) ...[
                              const SizedBox(height: 12),
                              TextField(
                                controller: customFontController,
                                decoration: const InputDecoration(
                                  labelText: 'Custom font-family value',
                                  hintText:
                                      'e.g. "Fira Sans", Arial, sans-serif',
                                ),
                              ),
                            ],
                          ],
                        ),
                        actions: [
                          TextButton(
                            style:
                                ButtonStyle(overlayColor: noHoverOverlay),
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                          if (currentHost != null &&
                              hasSiteRule &&
                              applyToCurrentSite)
                            TextButton(
                              style:
                                  ButtonStyle(overlayColor: noHoverOverlay),
                              onPressed: () {
                                Navigator.of(context).pop(
                                  const _FontPickerResult(
                                    fontFamily: '',
                                    applyToCurrentSite: true,
                                    clearCurrentSiteRule: true,
                                  ),
                                );
                              },
                              child: const Text('Clear Site Rule'),
                            ),
                          TextButton(
                            style:
                                ButtonStyle(overlayColor: noHoverOverlay),
                            onPressed: () {
                              final chosenFont =
                                  selectedValue == customOptionValue
                                      ? customFontController.text.trim()
                                      : selectedValue;
                              Navigator.of(context).pop(
                                _FontPickerResult(
                                  fontFamily: chosenFont,
                                  applyToCurrentSite: currentHost != null &&
                                      applyToCurrentSite,
                                ),
                              );
                            },
                            child: const Text('Apply'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    customFontController.dispose();

    if (!mounted || result == null) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    if (result.applyToCurrentSite && currentHost != null) {
      if (result.clearCurrentSiteRule) {
        if (!_siteFontFamilies.containsKey(currentHost)) return;
        setState(() {
          _siteFontFamilies.remove(currentHost);
        });
        await _persistFontOverrides();
      } else {
        if ((_siteFontFamilies[currentHost] ?? '') == result.fontFamily) return;
        setState(() {
          _siteFontFamilies[currentHost] = result.fontFamily;
        });
        await _persistFontOverrides();
      }
    } else {
      if (result.fontFamily == _pageFontFamily) return;
      await prefs.setString(pageFontFamilyKey, result.fontFamily);
      setState(() {
        _pageFontFamily = result.fontFamily;
      });
    }

    await _applyFontOverrideToAllTabs();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.clearCurrentSiteRule
              ? 'Site font rule removed'
              : result.fontFamily.isEmpty
                  ? 'Font override disabled'
                  : 'Page font updated',
        ),
      ),
    );
  }

  void _showNetworkDebug() async {
    await _showWithModalInteractionBlock<void>(
      () => showDialog(
        context: context,
        builder: (context) => const NetworkDebugDialog(),
      ),
    );
  }

  Future<void> _handleMenuSelection(String value) async {
    switch (value) {
      case 'add_bookmark':
        _addBookmark();
        break;
      case 'view_bookmarks':
        _showBookmarks();
        break;
      case 'history':
        _showHistory();
        break;
      case 'ai_chat':
        _showAiChat();
        break;
      case 'settings':
        _showSettings();
        break;
      case 'page_font':
        _showFontPicker();
        break;
      case 'git_fetch':
        _showGitFetchDialog();
        break;
      case 'network_debug':
        _showNetworkDebug();
        break;
      case 'whats_new':
        if (widget.onShowWhatsNew != null) {
          await _showWithModalInteractionBlock<void>(widget.onShowWhatsNew!);
        }
        break;
    }
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required String value,
    required IconData icon,
    required String label,
  }) {
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        _isOverflowMenuHovered = true;
        _cancelOverflowMenuClose();
      },
      onExit: (_) {
        _isOverflowMenuHovered = false;
        _scheduleOverflowMenuClose();
      },
      child: GestureDetector(
        onTap: () {
          _overflowMenuController.close();
          unawaited(_handleMenuSelection(value));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildMenuEntries(BuildContext context) {
    return [
      _buildMenuItem(
        context,
        value: 'add_bookmark',
        icon: Icons.bookmark_add,
        label: 'Add Bookmark',
      ),
      _buildMenuItem(
        context,
        value: 'view_bookmarks',
        icon: Icons.bookmarks,
        label: 'Bookmarks',
      ),
      _buildMenuItem(
        context,
        value: 'history',
        icon: Icons.history,
        label: 'History',
      ),
      if (widget.enableGitFetch)
        _buildMenuItem(
          context,
          value: 'git_fetch',
          icon: Icons.code,
          label: 'Git Fetch',
        ),
      if (widget.aiAvailable)
        _buildMenuItem(
          context,
          value: 'ai_chat',
          icon: Icons.smart_toy,
          label: 'AI Chat',
        ),
      _buildMenuItem(
        context,
        value: 'page_font',
        icon: Icons.font_download,
        label: 'Page Font',
      ),
      _buildMenuItem(
        context,
        value: 'settings',
        icon: Icons.settings,
        label: 'Settings',
      ),
      _buildMenuItem(
        context,
        value: 'whats_new',
        icon: Icons.new_releases_outlined,
        label: "What's New",
      ),
      _buildMenuItem(
        context,
        value: 'network_debug',
        icon: Icons.network_check,
        label: 'Network Debug',
      ),
    ];
  }

  Widget _buildMenuButton({double iconSize = 24}) {
    return MenuAnchor(
      controller: _overflowMenuController,
      consumeOutsideTap: true,
      style: MenuStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        minimumSize: const WidgetStatePropertyAll(Size(180, 0)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 4),
        ),
      ),
      onClose: () {
        _isOverflowMenuHovered = false;
        _isOverflowTriggerHovered = false;
        _cancelOverflowMenuClose();
        _setOverflowMenuOpen(false);
      },
      menuChildren: _buildMenuEntries(context),
      builder: (context, controller, child) {
        return MouseRegion(
          onEnter: (_) {
            _isOverflowTriggerHovered = true;
            _cancelOverflowMenuClose();
          },
          onExit: (_) {
            _isOverflowTriggerHovered = false;
            _scheduleOverflowMenuClose();
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                if (controller.isOpen) {
                  controller.close();
                  _setOverflowMenuOpen(false);
                  return;
                }
                controller.open();
                _setOverflowMenuOpen(true);
              },
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.more_vert,
                    size: iconSize,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showGitFetchDialog() {
    showDialog(
      context: context,
      builder: (context) => GitFetchDialog(
        onOpenInNewTab: (url) {
          final uri = Uri.tryParse(url);
          if (uri == null) {
            logger.w('Invalid URL: $url');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invalid URL')),
            );
            return; // Don't create a new tab for an invalid URL
          }

          _addNewTab();
          activeTab.currentUrl = url;
          activeTab.urlController.text = url;
          try {
            activeTab.webViewController?.loadRequest(uri);
          } on PlatformException catch (e, s) {
            if (!_isMissingPluginException(e)) {
              logger.w(
                  'Unexpected PlatformException on loadRequest (Git Fetch)',
                  error: e,
                  stackTrace: s);
            }
          }
        },
      ),
    );
  }

  Future<void> _showAiChat() async {
    if (!widget.aiAvailable) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI is not available in this build')));
      return;
    }
    final activeTab = tabs[tabController.index];
    String? pageTitle;
    String? pageUrl;
    try {
      final titleResult = await activeTab.webViewController
          ?.runJavaScriptReturningResult('document.title');
      if (titleResult != null && titleResult is String) {
        pageTitle = titleResult;
      }
      final urlResult = await activeTab.webViewController
          ?.runJavaScriptReturningResult('window.location.href');
      if (urlResult != null && urlResult is String) {
        pageUrl = urlResult;
      }
    } catch (e) {
      debugPrint('Error fetching page info: $e');
    }
    await _showWithModalInteractionBlock<void>(
      () => showDialog(
        context: context,
        builder: (context) =>
            AiChatWidget(pageTitle: pageTitle, pageUrl: pageUrl),
      ),
    );
  }

  List<String> _fallbackSearchSuggestions() {
    return const [
      'best hidden travel places in 2026',
      'latest space discoveries this week',
      'beginner friendly side project ideas',
      'healthy 20 minute dinner recipes',
      'best documentaries to watch this month',
      'top open source tools for productivity',
    ];
  }

  List<String> _parseAiSuggestions(String raw) {
    final seen = <String>{};
    final output = <String>[];
    final lines = raw.split('\n');
    for (final line in lines) {
      var cleaned = line.trim();
      if (cleaned.isEmpty) continue;
      cleaned = cleaned.replaceAll(RegExp(r'^[-*•\d\.\)\s]+'), '').trim();
      if (cleaned.length < 4) continue;
      if (_isDisallowedAiSuggestion(cleaned)) continue;
      if (seen.add(cleaned.toLowerCase())) {
        output.add(cleaned);
      }
      if (output.length >= 6) break;
    }
    return output;
  }

  bool _isDisallowedAiSuggestion(String suggestion) {
    return suggestion.trim().toLowerCase().startsWith('file://');
  }

  Future<List<String>> _fetchAiSearchSuggestions() async {
    final now = DateTime.now();
    final isCacheFresh = _cachedAiSearchSuggestions != null &&
        _lastAiSuggestionFetchAt != null &&
        now.difference(_lastAiSuggestionFetchAt!) < const Duration(minutes: 20);
    if (isCacheFresh) {
      return _cachedAiSearchSuggestions!;
    }

    List<String> suggestions;
    if (!widget.aiAvailable) {
      suggestions = _fallbackSearchSuggestions();
    } else {
      try {
        final response = await _aiService?.generateResponse(
              'Suggest 6 short, interesting web search ideas for a general audience. '
              'Return only one idea per line. No numbering. No extra text.',
            ) ??
            '';
        final parsed = _parseAiSuggestions(response);
        suggestions = parsed.isEmpty ? _fallbackSearchSuggestions() : parsed;
      } catch (_) {
        suggestions = _fallbackSearchSuggestions();
      }
    }

    _cachedAiSearchSuggestions = suggestions;
    _lastAiSuggestionFetchAt = now;
    return suggestions;
  }

  Future<void> _showAiSearchSuggestionsSheet() async {
    final theme = Theme.of(context);
    final suggestionsFuture = _fetchAiSearchSuggestions();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: false,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: FutureBuilder<List<String>>(
          future: suggestionsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final suggestions = snapshot.data ?? _fallbackSearchSuggestions();
            return SizedBox(
              key: const Key('browser.ai_suggestions_sheet'),
              height: 260,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 2, 14, 6),
                    child: Text(
                      key: const Key('browser.ai_suggestions_title'),
                      'Explore with AI',
                      style: theme.textTheme.titleSmall?.copyWith(fontSize: 14),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: suggestions.length,
                      itemBuilder: (context, index) {
                        final suggestion = suggestions[index];
                        return ListTile(
                          dense: true,
                          visualDensity:
                              const VisualDensity(horizontal: -2, vertical: -2),
                          hoverColor: Colors.transparent,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 14),
                          minLeadingWidth: 18,
                          leading: Icon(
                            Icons.auto_awesome,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          title: Text(
                            suggestion,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontSize: 13),
                          ),
                          onTap: () async {
                            activeTab.urlFocusNode.unfocus();
                            _setUrlAutocompleteOpen(false);
                            if (_isDisallowedAiSuggestion(suggestion)) {
                              Navigator.of(context).pop();
                              if (mounted) {
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Blocked unsafe local file suggestion',
                                    ),
                                  ),
                                );
                              }
                              return;
                            }
                            Navigator.of(context).pop();
                            await Future<void>.delayed(Duration.zero);
                            if (!mounted) return;
                            FocusManager.instance.primaryFocus?.unfocus();
                            activeTab.urlFocusNode.unfocus();
                            await _loadUrl(suggestion);
                            if (!mounted) return;
                            activeTab.urlController.selection =
                                TextSelection.collapsed(
                              offset: activeTab.urlController.text.length,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showHistory() async {
    if (widget.privateBrowsing) {
      await _showWithModalInteractionBlock<void>(
        () => showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('History'),
            content:
                const Text('History is not saved in private browsing mode'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      );
      return;
    }
    final history = _history;
    await _showWithModalInteractionBlock<void>(
      () => showDialog(
        context: context,
        builder: (context) {
          final theme = Theme.of(context);
          final dialogTheme = theme.copyWith(
            splashFactory: NoSplash.splashFactory,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
          );
          return Theme(
            data: dialogTheme,
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                final displayHistory =
                    history.reversed.toList(growable: false);
                return AlertDialog(
                  title: Text(
                    'History',
                    style: theme.textTheme.titleSmall?.copyWith(fontSize: 15),
                  ),
                  content: history.isEmpty
                      ? const Text('No history')
                      : SizedBox(
                          width: double.maxFinite,
                          height: 300,
                          child: ListView.builder(
                            itemCount: displayHistory.length,
                            itemBuilder: (context, index) {
                              final entry = displayHistory[index];
                              return ListTile(
                                dense: true,
                                visualDensity: const VisualDensity(
                                    horizontal: -2, vertical: -2),
                                title: Text(
                                  entry,
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(fontSize: 12),
                                ),
                                hoverColor: Colors.transparent,
                                onTap: () {
                                  Navigator.of(context).pop();
                                  _loadUrl(entry);
                                },
                                trailing: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        final removeIndex =
                                            history.length - 1 - index;
                                        if (removeIndex >= 0 &&
                                            removeIndex < history.length) {
                                          history.removeAt(removeIndex);
                                        }
                                      });
                                      setDialogState(() {});
                                      _saveHistory();
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Icon(Icons.delete,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          history.clear();
                          for (final tab in tabs) {
                            tab.history.clear();
                          }
                        });
                        setDialogState(() {});
                        _saveHistory();
                        Navigator.of(context).pop();
                      },
                      child: const Text('Clear All'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Iterable<String> _historyUrlSuggestions(String rawInput) {
    final query = rawInput.trim().toLowerCase();
    if (query.isEmpty) return const <String>[];

    final seen = <String>{};
    final matches = <String>[];
    for (final url in _history.reversed) {
      final normalized = url.trim();
      if (normalized.isEmpty) continue;
      final lower = normalized.toLowerCase();
      if (!lower.contains(query)) continue;
      if (!seen.add(lower)) continue;
      matches.add(normalized);
      if (matches.length >= 8) break;
    }

    matches.sort((a, b) {
      final aStarts = a.toLowerCase().startsWith(query);
      final bStarts = b.toLowerCase().startsWith(query);
      if (aStarts != bStarts) return aStarts ? -1 : 1;
      return a.length.compareTo(b.length);
    });
    return matches;
  }

  Future<void> _showQuickUrlPrompt() async {
    var inputValue =
        activeTab.currentUrl == defaultHomepageUrl ? '' : activeTab.currentUrl;
    var dialogClosed = false;
    final theme = Theme.of(context);
    final submittedValue = await showDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) {
        void closeDialog([String? value]) {
          if (dialogClosed) return;
          dialogClosed = true;
          Navigator.of(dialogContext).pop(value);
        }

        return AlertDialog(
          contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Search or URL',
                style: theme.textTheme.titleSmall?.copyWith(fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: inputValue,
                autofocus: true,
                textInputAction: TextInputAction.go,
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'enter url or search',
                  hintStyle: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                  isDense: true,
                  filled: false,
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                onChanged: (value) {
                  inputValue = value;
                },
                onFieldSubmitted: (value) {
                  Future<void>.delayed(Duration.zero, () {
                    closeDialog(value);
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => closeDialog(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => closeDialog(inputValue),
              child: const Text('Go'),
            ),
          ],
        );
      },
    );

    final value = submittedValue?.trim();
    if (value == null || value.isEmpty) return;
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    await _loadUrl(value);
  }

  Future<void> _loadUrl(String url) async {
    if (_urlAutocompleteOpen && mounted) {
      setState(() => _urlAutocompleteOpen = false);
      _syncPagePointerEvents(activeTab);
    }

    // Clear forward URL when loading a new URL
    activeTab.forwardUrl = null;

    // Handle about: URLs with strict allowlist
    if (url.startsWith('about:')) {
      // Only allow trusted internal about: URLs
      const allowedAboutUrls = {
        'about:browser-home',
        'about:blank',
      };

      if (!allowedAboutUrls.contains(url)) {
        logger.w('Blocked invalid about: URL: $url');
        if (mounted) {
          setState(() {
            activeTab.currentUrl = url;
            activeTab.urlController.text = url;
            activeTab.state = const BrowserState.error('Invalid internal URL.');
          });
        }
        return;
      }

      // Only about:browser-home is internal-only; about:blank loads in WebView
      if (url == 'about:browser-home') {
        if (mounted) {
          setState(() {
            activeTab.currentUrl = url;
            activeTab.urlController.text = _displayUrl(url);
            activeTab.faviconUrl = _defaultFaviconUrlFor(url);
            activeTab.webViewController = null;
            activeTab.state = BrowserState.success(url);
          });
        }
        return;
      }
      // about:blank falls through to normal WebView load
    }

    final wasOnHome = activeTab.currentUrl == defaultHomepageUrl;
    final processedUrl = UrlUtils.processUrl(url);

    if (!UrlUtils.isValidUrl(processedUrl)) {
      logger.w('Invalid or unsafe URL: $processedUrl');
      if (mounted) {
        setState(() {
          activeTab.currentUrl = url;
          activeTab.urlController.text = url;
          activeTab.state =
              const BrowserState.error('That address does not look valid.');
        });
      }
      return;
    }
    activeTab.currentUrl = processedUrl;
    activeTab.urlController.text = _displayUrl(processedUrl);
    activeTab.hideStaleWebViewUntilPageFinish = wasOnHome;
    if (activeTab.webViewController == null && mounted) {
      setState(() {});
    }
    try {
      if (processedUrl.startsWith('file:///') ||
          processedUrl.startsWith('file://')) {
        final path = processedUrl.replaceFirst('file://', '');
        await activeTab.webViewController?.loadFile(path);
      } else {
        activeTab.webViewController?.loadRequest(Uri.parse(processedUrl));
      }
    } on PlatformException catch (e, s) {
      if (!_isMissingPluginException(e)) {
        logger.w('Unexpected PlatformException on loadUrl',
            error: e, stackTrace: s);
      }
    }
  }

  void _performTorrySearch(TabData tab, [String? text]) {
    final query = (text ?? tab.torrySearchController.text).trim();
    if (query.isEmpty) {
      tab.torrySearchFocusNode.requestFocus();
      return;
    }
    final targetUrl =
        'https://www.torry.io/search/?q=${Uri.encodeQueryComponent(query)}';
    _loadUrl(targetUrl);
  }

  Widget _buildTorryHomeView(TabData tab) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      color: colorScheme.surface,
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.security,
                      size: 36,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Private search via torry.io.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: colorScheme.outline.withValues(alpha: 0.45),
                      ),
                    ),
                    child: TextField(
                      controller: tab.torrySearchController,
                      focusNode: tab.torrySearchFocusNode,
                      textInputAction: TextInputAction.search,
                      textAlignVertical: TextAlignVertical.center,
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                      onSubmitted: (s) => _performTorrySearch(tab, s),
                      decoration: InputDecoration(
                        hintText: 'Search',
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10),
                        prefixIcon: Icon(
                          Icons.search,
                          color: colorScheme.primary,
                          size: 18,
                        ),
                        prefixIconConstraints:
                            const BoxConstraints(minHeight: 36, minWidth: 42),
                        suffixIcon: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () => _performTorrySearch(tab),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                Icons.arrow_forward,
                                color: colorScheme.primary,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: () =>
                            _loadUrl('https://www.torry.io/learn/directory/'),
                        icon: const Icon(Icons.list),
                        label: const Text(
                          'Onion directory',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            _loadUrl('https://www.torry.io/anonymous-view/'),
                        icon: const Icon(Icons.visibility),
                        label: const Text(
                          'Anonymous view',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView(TabData tab) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final errorActionColor = colorScheme.onSurface;
    final noHoverOverlay = WidgetStateProperty.resolveWith<Color?>((states) {
      return states.contains(WidgetState.hovered) ? Colors.transparent : null;
    });
    final errorMessage = tab.state is BrowserError
        ? (tab.state as BrowserError).message
        : 'We could not load that page.';
    return Container(
      color: colorScheme.surface,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.public_off,
                size: 42,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Browser',
              style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Sorry, we can’t open this page.',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: colorScheme.onSurface,
                fontSize: 24,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              errorMessage,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                if (tab.webViewController != null)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ).copyWith(
                      overlayColor: noHoverOverlay,
                      elevation: WidgetStateProperty.resolveWith<double?>(
                        (states) =>
                            states.contains(WidgetState.hovered) ? 0 : null,
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        tab.state = const BrowserState.idle();
                      });
                      tab.webViewController?.reload();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                  ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: errorActionColor,
                    side: BorderSide(
                      color: errorActionColor.withValues(alpha: 0.45),
                    ),
                    visualDensity: VisualDensity.compact,
                  ).copyWith(overlayColor: noHoverOverlay),
                  onPressed: () {
                    if (widget.hideAppBar) {
                      _showQuickUrlPrompt();
                    } else {
                      tab.urlFocusNode.requestFocus();
                    }
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit URL'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBody(TabData tab) {
    if (tab.currentUrl == defaultHomepageUrl) {
      return _buildTorryHomeView(tab);
    }
    if (tab.state is BrowserError) {
      return _buildErrorView(tab);
    }
    if (defaultTargetPlatform == TargetPlatform.macOS && isIntegrationTest) {
      return const Center(
        child: Text('WebView disabled in integration tests.'),
      );
    }

    if (tab.webViewController == null) {
      tab.webViewController = WebViewController();
      tab.webViewController!.setJavaScriptMode(widget.strictMode
          ? JavaScriptMode.disabled
          : JavaScriptMode.unrestricted);
      // Note: webview_flutter does not support built-in private browsing.
      // Cache is not stored for private tabs (LOAD_NO_CACHE equivalent not available).
      // Cookies are shared globally; private browsing does not clear them.
      // This is a limitation compared to flutter_inappwebview.
      // Partial workaround for SPA history: listen for popstate events via JS.
      tab.webViewController!.addJavaScriptChannel('HistoryChannel',
          onMessageReceived: (JavaScriptMessage message) {
        final url = message.message;
        // Validate URL to prevent LFI and spoofing attacks
        if (!_isValidHistoryUrl(url)) {
          logger.w('Blocked invalid URL from HistoryChannel: $url');
          return;
        }
        _recordHistory(tab, url);
        // Update the URL bar for SPA navigation
        if (!tab.isClosed && mounted && tab.currentUrl != url) {
          setState(() {
            tab.currentUrl = url;
            tab.urlController.text = url;
          });
        }
        _updateThemeFromTab(tab);
      });
      tab.webViewController!.addJavaScriptChannel('PageTapChannel',
          onMessageReceived: (JavaScriptMessage message) {
        if (!mounted || tab.isClosed) return;
        if (tab.urlFocusNode.hasFocus) {
          tab.urlFocusNode.unfocus();
        }
        if (_urlAutocompleteOpen) {
          _setUrlAutocompleteOpen(false);
        }
      });
      tab.webViewController!.addJavaScriptChannel('LoginDetector',
          onMessageReceived: (JavaScriptMessage message) async {
        final prefs = await SharedPreferences.getInstance();
        final passwordManagerEnabled =
            prefs.getBool(passwordManagerEnabledKey) ?? false;
        if (!passwordManagerEnabled) return;

        try {
          final data = jsonDecode(message.message) as Map<String, dynamic>;
          final credentials = LoginCredentials.fromJson(data);

          // Verify origin matches current tab URL to prevent spoofing
          final tabUri = Uri.parse(tab.currentUrl);
          final credentialUri = Uri.parse(credentials.origin);
          if (tabUri.origin != credentialUri.origin) return;

          final policy = SitePasswordPolicy(prefs: prefs);
          if (await policy.isNeverSave(credentials.origin)) return;

          if (mounted && !tab.isClosed) {
            setState(() {
              tab.pendingPasswordPrompt = SavePasswordPromptData(
                origin: credentials.origin,
                username: credentials.username,
                password: credentials.password,
              );
            });
          }
        } catch (e, s) {
          logger.w('Failed to parse login credentials from JS',
              error: e, stackTrace: s);
        }
      });
      tab.webViewController!.addJavaScriptChannel('WebAuthnChannel',
          onMessageReceived: (JavaScriptMessage message) async {
        logger.i('WebAuthn message received');
        _handleWebAuthnMessage(tab, message.message);
      });
      tab.webViewController!.setNavigationDelegate(NavigationDelegate(
        onPageStarted: (url) {
          if (!tab.isClosed) {
            if (mounted) {
              setState(() {
                tab.currentUrl = url;
                tab.urlController.text = tab.currentUrl;
                tab.state = const BrowserState.loading();
                tab.detectedBrightness = null;
                tab.detectedSeedColor = null;
                final host = _hostFromUrl(url);
                final nextFavicon = host != null
                    ? (_faviconCacheByHost[host] ?? _defaultFaviconUrlFor(url))
                    : _defaultFaviconUrlFor(url);
                if (nextFavicon != null && nextFavicon.isNotEmpty) {
                  tab.faviconUrl = nextFavicon;
                }
                _recordHistory(tab, tab.currentUrl);
              });
            }
            _syncPagePointerEvents(tab);
          }
        },
        onPageFinished: (url) {
          tab.hideStaleWebViewUntilPageFinish = false;
          if (mounted) {
            setState(() {
              if (tab.state is! BrowserError) {
                tab.state = BrowserState.success(url);
              }
            });
          }
          // Add listeners for SPA navigations: popstate, pushState, replaceState
          if (tab.webViewController != null) {
            tab.webViewController!.runJavaScript('''
            if (!window.historyListenerAdded) {
              window.addEventListener('popstate', function(event) {
                HistoryChannel.postMessage(window.location.href);
              });
              // Override pushState and replaceState to capture programmatic changes
              window.originalPushState = window.history.pushState;
              window.history.pushState = function(state, title, url) {
                window.originalPushState.call(this, state, title, url);
                HistoryChannel.postMessage(window.location.href);
              };
              window.originalReplaceState = window.history.replaceState;
              window.history.replaceState = function(state, title, url) {
                window.originalReplaceState.call(this, state, title, url);
                HistoryChannel.postMessage(window.location.href);
              };
              window.historyListenerAdded = true;
            }
            if (!window.pageTapListenerAdded) {
              const notifyTap = function() {
                try { PageTapChannel.postMessage('tap'); } catch (_) {}
              };
              window.addEventListener('pointerdown', notifyTap, true);
              window.pageTapListenerAdded = true;
            }
          ''');
            // Inject login detection script
            tab.webViewController!.runJavaScript(loginDetectionScript);
            // Inject WebAuthn script
            tab.webViewController!.runJavaScript(webAuthnScript);
            _applyLegacyLayoutFix(tab);
            _applyFontOverride(tab);
            _updateTabFavicon(tab);
            // Attempt autofill if credentials available
            _attemptAutofill(tab);
          }
          _syncPagePointerEvents(tab);
          _updateThemeFromTab(tab);
          Future.delayed(const Duration(milliseconds: 400), () {
            if (!mounted) return;
            _updateThemeFromTab(tab);
          });
          Future.delayed(const Duration(milliseconds: 1200), () {
            if (!mounted) return;
            _updateThemeFromTab(tab);
          });
        },
        onNavigationRequest: (request) {
          if (!_isAllowedNavigationUrl(request.url)) {
            _logBlockedNavigation(tab, request.url);
            return NavigationDecision.prevent;
          }
          if (_isDownloadUrl(request.url)) {
            _downloadFile(request.url);
            return NavigationDecision.prevent;
          }
          _maybeDownloadByHeaders(request.url);
          if (widget.adBlocking &&
              adBlockerPatterns
                  .any((pattern) => pattern.hasMatch(request.url.toString()))) {
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
        onWebResourceError: (error) {
          if (_shouldIgnoreWebResourceError(error)) {
            quietLogger.w(
              'Ignoring benign web resource error: ${error.errorCode} ${error.description}',
            );
            if (mounted && tab.state is Loading) {
              setState(() {
                tab.state = BrowserState.success(tab.currentUrl);
              });
            }
            return;
          }
          _handleLoadError(tab, error.description);
        },
        onHttpError: (error) {
          _handleLoadError(tab, 'HTTP ${error.response?.statusCode}');
        },
      ));
      _syncPagePointerEvents(tab);
      _loadInitialRequestForTab(tab);
    }

    try {
      return KeepAliveWrapper(
        child: Stack(
          children: [
            WebViewWidget(controller: tab.webViewController!),
            if (tab.hideStaleWebViewUntilPageFinish)
              Positioned.fill(
                child: ColoredBox(
                  color: Theme.of(context).colorScheme.surface,
                ),
              ),
            if (tab.state is Loading)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            if (tab.pendingPasswordPrompt != null && activeTab == tab)
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: SavePasswordPrompt(
                  origin: tab.pendingPasswordPrompt!.origin,
                  username: tab.pendingPasswordPrompt!.username,
                  onAction: (action) => _handlePasswordPromptAction(action),
                ),
              ),
          ],
        ),
      );
    } catch (e, s) {
      logger.e('Error creating WebView: $e\n$s');
      return const Center(
        child: Text('Failed to load browser.'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMacDesktop = defaultTargetPlatform == TargetPlatform.macOS;
    final leadingInset = (isMacDesktop && !widget.hideAppBar)
        ? _kMacOsLeadingInsetWithTrafficLights
        : _kDefaultLeadingInset;
    final addressBarLeftOffset = (isMacDesktop && !widget.hideAppBar)
        ? _kMacOsAddressBarLeftOffset
        : 0.0;

    final PreferredSizeWidget? appBarWidget = widget.hideAppBar
        ? null
        : AppBar(
            primary: false,
            toolbarHeight: 52,
            actions: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClickableIcon(
                      icon: Icons.arrow_back_ios,
                      size: 16,
                      onTap: _goBack,
                    ),
                    ClickableIcon(
                      icon: Icons.arrow_forward_ios,
                      size: 16,
                      onTap: _goForward,
                    ),
                  ],
                ),
              ),
              ClickableIcon(
                icon: Icons.add,
                size: 22,
                onTap: _addNewTab,
              ),
              _buildMenuButton(),
            ],
            title: Container(
              margin: EdgeInsets.only(left: addressBarLeftOffset),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  SizedBox(width: leadingInset),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () {
                        final text = activeTab.urlController.text;
                        if (text.isNotEmpty) {
                          final decision = resolveUrlSubmission(
                            submittedValue: text,
                            aiSearchSuggestionsEnabled:
                                widget.aiSearchSuggestionsEnabled,
                          );
                          if (decision.shouldShowAiSuggestions) {
                            _showAiSearchSuggestionsSheet();
                          }
                          if (decision.shouldLoadUrl) {
                            _loadUrl(decision.normalizedInput);
                          }
                        }
                      },
                      child: Icon(
                        Icons.search,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RawAutocomplete<String>(
                      focusNode: activeTab.urlFocusNode,
                      textEditingController: activeTab.urlController,
                      optionsBuilder: (value) =>
                          _historyUrlSuggestions(value.text),
                      onSelected: (value) {
                        activeTab.urlFocusNode.unfocus();
                        _setUrlAutocompleteOpen(false);
                        _loadUrl(value);
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        final optionList = options.toList(growable: false);
                        if (optionList.isEmpty) {
                          _setUrlAutocompleteOpen(false);
                          return const SizedBox.shrink();
                        }
                        _setUrlAutocompleteOpen(true);
                        final theme = Theme.of(context);
                        return Stack(
                          children: [
                            InteractionBlocker(
                              onTap: () {
                                activeTab.urlFocusNode.unfocus();
                                _setUrlAutocompleteOpen(false);
                              },
                            ),
                            Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 6,
                                color: theme.colorScheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(12),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxHeight: 240,
                                    minWidth: 300,
                                    maxWidth: 720,
                                  ),
                                  child: ListView.builder(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 6),
                                    shrinkWrap: true,
                                    itemCount: optionList.length,
                                    itemBuilder: (context, index) {
                                      final option = optionList[index];
                                      return InkWell(
                                        onTap: () => onSelected(option),
                                        hoverColor: Colors.transparent,
                                        splashColor: Colors.transparent,
                                        highlightColor: Colors.transparent,
                                        focusColor: Colors.transparent,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          child: Text(
                                            option,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                      fieldViewBuilder:
                          (context, controller, focusNode, onFieldSubmitted) {
                        return TextField(
                          key: const Key('browser.url_field'),
                          controller: controller,
                          focusNode: focusNode,
                          onTapOutside: (_) {
                            focusNode.unfocus();
                            _setUrlAutocompleteOpen(false);
                          },
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search or enter URL',
                            hintStyle: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 13,
                            ),
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onTap: () {
                            if (widget.aiSearchSuggestionsEnabled &&
                                controller.text.trim().isEmpty) {
                              _showAiSearchSuggestionsSheet();
                            }
                          },
                          onSubmitted: (value) {
                            _setUrlAutocompleteOpen(false);
                            focusNode.unfocus();
                            final decision = resolveUrlSubmission(
                              submittedValue: value,
                              aiSearchSuggestionsEnabled:
                                  widget.aiSearchSuggestionsEnabled,
                            );
                            if (decision.shouldShowAiSuggestions) {
                              _showAiSearchSuggestionsSheet();
                            }
                            if (decision.shouldLoadUrl) {
                              _loadUrl(decision.normalizedInput);
                            }
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(right: leadingInset),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: _refresh,
                        child: RotationTransition(
                          turns: _refreshIconController,
                          child: Icon(
                            Icons.refresh,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
    final double topToolbarInset =
        (isMacDesktop && !widget.hideAppBar) ? _kMacOsTopToolbarInset : 0.0;

    return DropTarget(
      onDragEntered: (details) => setState(() => _dragging = true),
      onDragExited: (details) => setState(() => _dragging = false),
      onDragDone: (details) async {
        setState(() => _dragging = false);
        if (details.files.isNotEmpty) {
          final file = details.files.first;
          final path = 'file://${file.path}';
          if (tabs.isEmpty) {
            _addNewTab();
          }
          _loadUrl(path);
        }
      },
      child: Scaffold(
        appBar: topToolbarInset > 0 && appBarWidget != null
            ? PreferredSize(
                preferredSize:
                    Size.fromHeight(kToolbarHeight + topToolbarInset),
                child: Column(
                  children: [
                    Container(
                      height: topToolbarInset,
                      color: Theme.of(context).colorScheme.surface,
                    ),
                    appBarWidget,
                  ],
                ),
              )
            : appBarWidget,
        body: Stack(
          children: [
            Column(
              children: [
                Container(
                  height: 34,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      bottom: BorderSide(
                        color: widget.themeMode == AppThemeMode.adjust
                            ? Colors.transparent
                            : Theme.of(context)
                                .colorScheme
                                .outline
                                .withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: MouseRegion(
                    onEnter: (_) {
                      if (defaultTargetPlatform == TargetPlatform.macOS &&
                          widget.hideAppBar &&
                          _reorderableTabs) {
                        _setWindowMovable(false);
                      }
                    },
                    onExit: (_) {
                      if (defaultTargetPlatform == TargetPlatform.macOS &&
                          widget.hideAppBar &&
                          _reorderableTabs) {
                        _setWindowMovable(true);
                      }
                    },
                    child: Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: (_) {
                        if (widget.hideAppBar && _reorderableTabs) {
                          _setWindowMovable(false);
                        }
                      },
                      onPointerUp: (_) {
                        if (widget.hideAppBar && _reorderableTabs) {
                          _setWindowMovable(true);
                        }
                      },
                      onPointerCancel: (_) {
                        if (widget.hideAppBar && _reorderableTabs) {
                          _setWindowMovable(true);
                        }
                      },
                      child: _reorderableTabs
                          ? ReorderableListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: tabs.length,
                              onReorder: _reorderTab,
                              onReorderStart: (_) {
                                _setWindowMovable(false);
                              },
                              onReorderEnd: (_) {
                                _setWindowMovable(true);
                              },
                              buildDefaultDragHandles: false,
                              itemBuilder: (context, index) {
                                final tab = tabs[index];
                                final isSelected = tabController.index == index;
                                return ReorderableDragStartListener(
                                  key: ObjectKey(tab),
                                  index: index,
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: GestureDetector(
                                      onTap: () => setState(
                                          () => tabController.index = index),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: isSelected
                                                  ? Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                  : Colors.transparent,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                        child: _buildTabItem(
                                            tab, index, isSelected,
                                            showDragHandle: true),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            )
                          : Theme(
                              data: Theme.of(context).copyWith(
                                hoverColor: Colors.transparent,
                                splashColor: Colors.transparent,
                                highlightColor: Colors.transparent,
                              ),
                              child: TabBar(
                                controller: tabController,
                                isScrollable: true,
                                tabAlignment: TabAlignment.start,
                                padding: EdgeInsets.zero,
                                overlayColor:
                                    WidgetStateProperty.all(Colors.transparent),
                                indicatorColor:
                                    widget.themeMode == AppThemeMode.adjust
                                        ? Colors.transparent
                                        : Theme.of(context).colorScheme.primary,
                                dividerColor:
                                    widget.themeMode == AppThemeMode.adjust
                                        ? Colors.transparent
                                        : Theme.of(context)
                                            .colorScheme
                                            .outline
                                            .withValues(alpha: 0.2),
                                labelColor:
                                    Theme.of(context).colorScheme.onSurface,
                                unselectedLabelColor: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.6),
                                tabs: tabs.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final tab = entry.value;
                                  final isSelected =
                                      tabController.index == index;
                                  return Tab(
                                    height: 30,
                                    child:
                                        _buildTabItem(tab, index, isSelected),
                                  );
                                }).toList(),
                              ),
                            ),
                    ),
                  ),
                ),
                Expanded(
                  child: IgnorePointer(
                    ignoring:
                        activeTab.urlFocusNode.hasFocus || _urlAutocompleteOpen,
                    child: _reorderableTabs
                        ? IndexedStack(
                            index: tabController.index,
                            children:
                                tabs.map((tab) => _buildTabBody(tab)).toList(),
                          )
                        : TabBarView(
                            controller: tabController,
                            children:
                                tabs.map((tab) => _buildTabBody(tab)).toList(),
                          ),
                  ),
                ),
              ],
            ),
            if (widget.hideAppBar)
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: _goBack,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(Icons.arrow_back_ios,
                                size: 18,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant),
                          ),
                        ),
                      ),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: _goForward,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(Icons.arrow_forward_ios,
                                size: 18,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant),
                          ),
                        ),
                      ),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: _showQuickUrlPrompt,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(Icons.search,
                                size: 18,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant),
                          ),
                        ),
                      ),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: _refresh,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(Icons.refresh,
                                size: 18,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant),
                          ),
                        ),
                      ),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: _addNewTab,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(Icons.add,
                                size: 18,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant),
                          ),
                        ),
                      ),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: _showSettings,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(Icons.settings,
                                size: 18,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant),
                          ),
                        ),
                      ),
                      _buildMenuButton(iconSize: 18),
                    ],
                  ),
                ),
              ),
            if (_dragging)
              Container(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.1),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.file_open,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Drop file to open',
                        style: TextStyle(
                          fontSize: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (!_isOnline)
              Positioned(
                top: widget.hideAppBar ? 16 : 0,
                left: 0,
                right: 0,
                child: Material(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.wifi_off,
                          size: 16,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'No internet connection',
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onErrorContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
