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

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:file_selector/file_selector.dart';
import 'package:desktop_drop/desktop_drop.dart';

import '../constants.dart';
import '../features/theme_utils.dart';
import '../features/bookmark_manager.dart';
import '../features/password_prompt.dart';
import '../features/password_storage.dart';
import '../features/password_autofill.dart';
import '../features/login_detection.dart';
import '../browser_state.dart';

import '../features/video_manager.dart';
import '../logging/logger.dart';
import '../logging/network_monitor.dart';
import '../utils/string_utils.dart';
import '../utils/platform_utils.dart';
import 'package:pkg/ai_chat_widget.dart';
import 'network_debug_dialog.dart';
import 'save_password_prompt.dart';
import 'password_vault_screen.dart';

const _userAgents = {
  TargetPlatform.macOS: {
    'modern':
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0.2 Safari/605.1.15',
    'legacy':
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/50.0.0.0 Safari/537.36',
  },
  TargetPlatform.windows: {
    'modern':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0',
    'legacy':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/50.0.0.0 Safari/537.36',
  },
  TargetPlatform.linux: {
    'modern':
        'Mozilla/5.0 (X11; Linux x86_64; rv:120.0) Gecko/20100101 Firefox/120.0',
    'legacy':
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/50.0.0.0 Safari/537.36',
  },
};

String _getUserAgent(bool modern) {
  final platformAgents =
      _userAgents[defaultTargetPlatform] ?? _userAgents[TargetPlatform.macOS]!;
  final agentType = modern ? 'modern' : 'legacy';
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

class SettingsDialog extends HookWidget {
  const SettingsDialog({
    super.key,
    this.onSettingsChanged,
    this.onClearCaches,
    this.currentTheme,
    required this.aiAvailable,
  });

  final void Function()? onSettingsChanged;
  final void Function()? onClearCaches;
  final AppThemeMode? currentTheme;
  final bool aiAvailable;

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
    final homepage = useState<String?>(null);
    final hideAppBar = useState(false);
    final useModernUserAgent = useState(true);
    final enableGitFetch = useState(false);
    final privateBrowsing = useState(false);
    final originalPrivateBrowsing = useRef<bool?>(null);
    final adBlocking = useState(false);
    final strictMode = useState(false);
    final passwordManagerEnabled = useState(false);
    final selectedTheme =
        useState<AppThemeMode>(currentTheme ?? AppThemeMode.system);
    final homepageController = useTextEditingController();

    useEffect(() {
      Future<void> loadPreferences() async {
        final prefs = await SharedPreferences.getInstance();
        final storedHomepage = prefs.getString(homepageKey);
        final resolvedHomepage =
            (storedHomepage == null || storedHomepage.isEmpty)
                ? defaultHomepageUrl
                : storedHomepage;
        homepage.value = resolvedHomepage;
        homepageController.text =
            resolvedHomepage == defaultHomepageUrl ? '' : resolvedHomepage;
        hideAppBar.value = prefs.getBool(hideAppBarKey) ?? false;
        useModernUserAgent.value = prefs.getBool(useModernUserAgentKey) ?? true;
        enableGitFetch.value = prefs.getBool(enableGitFetchKey) ?? false;
        privateBrowsing.value = prefs.getBool(privateBrowsingKey) ?? false;
        originalPrivateBrowsing.value = privateBrowsing.value;
        adBlocking.value = prefs.getBool(adBlockingKey) ?? false;
        strictMode.value = prefs.getBool(strictModeKey) ?? false;
        passwordManagerEnabled.value =
            prefs.getBool(passwordManagerEnabledKey) ?? false;
        if (prefs.getString(themeModeKey) != null) {
          selectedTheme.value = AppThemeMode.values.firstWhere(
              (m) => m.name == prefs.getString(themeModeKey),
              orElse: () => currentTheme ?? AppThemeMode.system);
        }
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

    return AlertDialog(
      title: const Text('Settings'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: homepageController,
              decoration: const InputDecoration(labelText: 'Homepage'),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: Text(
                'Leave this blank to show the Browser welcome screen.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            SwitchListTile(
              title: const Text('Hide App Bar'),
              value: hideAppBar.value,
              onChanged: (value) => hideAppBar.value = value,
            ),
            SwitchListTile(
              title: const Text('Use Modern User Agent'),
              subtitle: const Text(
                  'Load modern Google interface (applies to new tabs)'),
              value: useModernUserAgent.value,
              onChanged: (value) => useModernUserAgent.value = value,
            ),
            SwitchListTile(
              title: const Text('Enable Git Fetch'),
              subtitle:
                  const Text('Show GitHub repository fetch option in menu'),
              value: enableGitFetch.value,
              onChanged: (value) => enableGitFetch.value = value,
            ),
            SwitchListTile(
              title: const Text('Private Browsing'),
              subtitle: const Text(
                  'Clear cache and cookies on toggle (shared globally)'),
              value: privateBrowsing.value,
              onChanged: (value) => privateBrowsing.value = value,
            ),
            SwitchListTile(
              title: const Text('Ad Blocking'),
              subtitle: const Text('Block common ad domains'),
              value: adBlocking.value,
              onChanged: (value) => adBlocking.value = value,
            ),
            SwitchListTile(
              title: const Text('Strict Mode'),
              subtitle:
                  const Text('Disable JavaScript and third-party cookies'),
              value: strictMode.value,
              onChanged: (value) => strictMode.value = value,
            ),
            SwitchListTile(
              title: const Text('Password Manager'),
              subtitle: const Text('Save passwords'),
              value: passwordManagerEnabled.value,
              onChanged: (value) => passwordManagerEnabled.value = value,
            ),
            if (passwordManagerEnabled.value)
              ListTile(
                leading: const Icon(Icons.lock),
                title: const Text('Manage Passwords'),
                subtitle: const Text('View and delete saved passwords'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const PasswordVaultScreen(),
                    ),
                  );
                },
              ),
            DropdownButton<AppThemeMode>(
              value: selectedTheme.value,
              onChanged: (AppThemeMode? value) {
                if (value != null) selectedTheme.value = value;
              },
              items: AppThemeMode.values
                  .map<DropdownMenuItem<AppThemeMode>>((AppThemeMode mode) {
                return DropdownMenuItem<AppThemeMode>(
                  value: mode,
                  child: Text('Theme: ${_themeLabel(mode)}'),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Chat',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    aiAvailable
                        ? 'Firebase configuration is present, so AI Chat is available.'
                        : 'Firebase keys are missing, so AI Chat will stay hidden.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Git Fetch requires GitHub access and only appears when '
                    'Enable Git Fetch is turned on.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
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
            await prefs.setString(themeModeKey, selectedTheme.value.name);

            onSettingsChanged?.call();
            if (privateBrowsing.value != originalPrivateBrowsing.value) {
              onClearCaches?.call();
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Settings saved')),
            );
            Navigator.of(context).pop();
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
    final repoController = useTextEditingController();
    final isLoading = useState(false);
    final repoData = useState<Map<String, dynamic>?>(null);
    final errorMessage = useState<String?>(null);

    Future<void> fetchRepo() async {
      final repo = repoController.text.trim();
      if (repo.isEmpty) return;

      final parts = repo.split('/');
      if (parts.length != 2) {
        errorMessage.value = 'Invalid format. Use owner/repo';
        return;
      }

      isLoading.value = true;
      errorMessage.value = null;
      repoData.value = null;

      try {
        final url = 'https://api.github.com/repos/${parts[0]}/${parts[1]}';
        final response = await _fetchGitHubRepo(url);
        isLoading.value = false;
        repoData.value = response;
      } catch (e) {
        isLoading.value = false;
        errorMessage.value = 'Failed to fetch repo: $e';
      }
    }

    return AlertDialog(
      title: const Text('Git Fetch'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: repoController,
            decoration: const InputDecoration(
              labelText: 'GitHub Repo (owner/repo)',
              hintText: 'e.g., flutter/flutter',
            ),
          ),
          const SizedBox(height: 16),
          if (isLoading.value) const CircularProgressIndicator(),
          if (errorMessage.value != null)
            Text(errorMessage.value!,
                style: const TextStyle(color: Colors.red)),
          if (repoData.value != null) ...[
            Text('Name: ${repoData.value!['name'] ?? 'N/A'}'),
            Text(
                'Description: ${repoData.value!['description'] ?? 'No description'}'),
            Text('Stars: ${repoData.value!['stargazers_count'] ?? 0}'),
            Text('Forks: ${repoData.value!['forks_count'] ?? 0}'),
            Text('Language: ${repoData.value!['language'] ?? 'N/A'}'),
            Text('Open Issues: ${repoData.value!['open_issues_count'] ?? 0}'),
          ],
        ],
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
      this.useModernUserAgent = true,
      this.enableGitFetch = false,
      this.privateBrowsing = false,
      this.adBlocking = false,
      this.strictMode = false,
      this.themeMode = AppThemeMode.system,
      this.aiAvailable = true,
      this.onSettingsChanged,
      this.onPageThemeChanged});

  final String initialUrl;
  final bool hideAppBar;
  final bool useModernUserAgent;
  final bool enableGitFetch;
  final bool privateBrowsing;
  final bool adBlocking;
  final bool strictMode;
  final AppThemeMode themeMode;
  final bool aiAvailable;
  final void Function()? onSettingsChanged;
  final void Function(ThemeMode mode, Color? seedColor)? onPageThemeChanged;

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

class _TelescopeLoader extends StatefulWidget {
  const _TelescopeLoader();

  @override
  State<_TelescopeLoader> createState() => _TelescopeLoaderState();
}

class _TelescopeLoaderState extends State<_TelescopeLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final faint = color.withValues(alpha: 0.28);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final sway = math.sin(t * 2 * math.pi) * 0.18;
        return SizedBox(
          width: 78,
          height: 78,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size.square(78),
                painter: _ScanRingPainter(progress: t, color: faint),
              ),
              Transform.rotate(
                angle: -0.55 + sway,
                child: Icon(
                  Icons.travel_explore,
                  size: 42,
                  color: color,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ScanRingPainter extends CustomPainter {
  const _ScanRingPainter({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width * 0.42;
    final basePaint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawCircle(center, radius, basePaint);

    final sweepPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final startAngle = (progress * 2 * math.pi) - (math.pi / 5);
    const sweepAngle = math.pi / 2.8;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      sweepPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class _BrowserPageState extends State<BrowserPage>
    with TickerProviderStateMixin {
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
  };

  late TabController tabController;
  final List<TabData> tabs = [];
  final bookmarkManager = BookmarkManager();
  late int previousTabIndex;
  List<RegExp> adBlockerPatterns = [];
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
  double _titleBarHeight = 0;
  bool _dragging = false;
  final FocusNode _keyboardFocusNode = FocusNode();

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
  const themeColor = document.querySelector('meta[name="theme-color"]')
    ?.getAttribute('content') || null;
  const metaColorScheme = document.querySelector('meta[name="color-scheme"]')
    ?.getAttribute('content') || null;
  const colorScheme = window.getComputedStyle(document.documentElement)
    .colorScheme || null;
  const textColor = window.getComputedStyle(document.body || document.documentElement)
    .color || null;
  const prefersDark = window.matchMedia &&
    window.matchMedia('(prefers-color-scheme: dark)').matches;
  return JSON.stringify({
    bg,
    sampleBg,
    themeColor,
    metaColorScheme,
    colorScheme,
    textColor,
    prefersDark
  });
})()
''';

  String _displayUrl(String url) => url == defaultHomepageUrl ? '' : url;

  @override
  void initState() {
    super.initState();
    if (defaultTargetPlatform == TargetPlatform.macOS && !isIntegrationTest) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final height = await windowManager.getTitleBarHeight();
          if (!mounted) return;
          setState(() {
            _titleBarHeight = height.toDouble();
          });
        } catch (e) {
          logger.w('Failed to read title bar height: $e');
        }
      });
    }
    tabs.add(
        TabData(widget.initialUrl, displayUrl: _displayUrl(widget.initialUrl)));
    tabController = TabController(length: 1, vsync: this);
    previousTabIndex = 0;
    tabController.addListener(_onTabChanged);
    _loadBookmarks();
    if (widget.adBlocking) {
      loadAdBlockers();
    }
  }

  @override
  void didUpdateWidget(covariant BrowserPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.themeMode != widget.themeMode) {
      if (widget.themeMode == AppThemeMode.adjust) {
        _applyThemeForTab(activeTab);
      } else {
        widget.onPageThemeChanged?.call(ThemeMode.system, null);
      }
    }
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
    if (result == null) return '';
    if (result is String) return result.trim();
    return result.toString().trim();
  }

  String _unescapeWrappedJson(String raw) {
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

  _ThemeTone? _toneFromProbe(Map<String, dynamic> probe) {
    final sampleBg =
        probe['sampleBg'] is String ? probe['sampleBg'] as String : null;
    final bg = probe['bg'] is String ? probe['bg'] as String : null;
    final themeColor =
        probe['themeColor'] is String ? probe['themeColor'] as String : null;
    final metaColorScheme = probe['metaColorScheme'] is String
        ? probe['metaColorScheme'] as String
        : null;
    final colorScheme =
        probe['colorScheme'] is String ? probe['colorScheme'] as String : null;
    final textColor =
        probe['textColor'] is String ? probe['textColor'] as String : null;
    final scheme = (metaColorScheme ?? colorScheme ?? '').toLowerCase();
    if (scheme.contains('dark') && !scheme.contains('light')) {
      return _ThemeTone(brightness: Brightness.dark);
    }
    if (scheme.contains('light') && !scheme.contains('dark')) {
      return _ThemeTone(brightness: Brightness.light);
    }
    final color = _parseCssColor(sampleBg) ??
        _parseCssColor(bg) ??
        _parseCssColor(themeColor);
    if (color != null) {
      final brightness =
          color.computeLuminance() < 0.5 ? Brightness.dark : Brightness.light;
      return _ThemeTone(brightness: brightness, seedColor: color);
    }
    final text = _parseCssColor(textColor);
    if (text != null) {
      final brightness =
          text.computeLuminance() < 0.5 ? Brightness.light : Brightness.dark;
      return _ThemeTone(brightness: brightness);
    }
    return null;
  }

  Color? _parseCssColor(String? value) {
    if (value == null) return null;
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'transparent') return null;
    if (normalized.startsWith('rgb')) {
      return _parseRgbColor(normalized);
    }
    if (normalized.startsWith('#')) {
      return _parseHexColor(normalized);
    }
    return null;
  }

  Color? _parseRgbColor(String value) {
    final match = RegExp(r'rgba?\\(([^)]+)\\)').firstMatch(value);
    if (match == null) return null;
    final parts = match.group(1)!.split(',').map((e) => e.trim()).toList();
    if (parts.length < 3) return null;
    final r = double.tryParse(parts[0]);
    final g = double.tryParse(parts[1]);
    final b = double.tryParse(parts[2]);
    if (r == null || g == null || b == null) return null;
    double alpha = 1.0;
    if (parts.length >= 4) {
      alpha = double.tryParse(parts[3]) ?? 1.0;
    }
    alpha = alpha.clamp(0.0, 1.0);
    if (alpha <= 0.05) return null;
    return Color.fromARGB(
      (alpha * 255).round(),
      _clampChannel(r),
      _clampChannel(g),
      _clampChannel(b),
    );
  }

  Color? _parseHexColor(String value) {
    var hex = value.substring(1);
    if (hex.length == 3) {
      hex = '${hex[0]}${hex[0]}${hex[1]}${hex[1]}${hex[2]}${hex[2]}';
    }
    if (hex.length == 6) {
      final rgb = int.tryParse(hex, radix: 16);
      if (rgb == null) return null;
      return Color.fromARGB(
        255,
        (rgb >> 16) & 0xFF,
        (rgb >> 8) & 0xFF,
        rgb & 0xFF,
      );
    }
    if (hex.length == 8) {
      final argb = int.tryParse(hex, radix: 16);
      if (argb == null) return null;
      return Color.fromARGB(
        (argb >> 24) & 0xFF,
        (argb >> 16) & 0xFF,
        (argb >> 8) & 0xFF,
        argb & 0xFF,
      );
    }
    return null;
  }

  int _clampChannel(double value) {
    return value.round().clamp(0, 255).toInt();
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
    if (previousTabIndex != tabController.index) {
      // Pause videos on previous tab
      final prevTab = tabs[previousTabIndex];
      if (prevTab.webViewController != null) {
        VideoManager.pauseVideos(prevTab.webViewController!);
      }
      // Resume videos on current tab
      final currTab = tabs[tabController.index];
      if (currTab.webViewController != null) {
        VideoManager.resumeVideos(currTab.webViewController!);
      }
    }
    previousTabIndex = tabController.index;
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

  bool _isAllowedNavigationUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return _allowedNavigationSchemes.contains(uri.scheme.toLowerCase());
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
        tabs.add(TabData(widget.initialUrl,
            displayUrl: _displayUrl(widget.initialUrl)));
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

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    for (final tab in tabs) {
      tab.urlController.dispose();
      tab.urlFocusNode.dispose();
      tab.torrySearchController.dispose();
      tab.torrySearchFocusNode.dispose();
    }
    tabController.dispose();
    _saveBookmarks();
    super.dispose();
  }

  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarksJson = prefs.getString('bookmarks');
    if (bookmarksJson != null) {
      try {
        bookmarkManager.load(bookmarksJson);
      } catch (e, s) {
        logger.w('Failed to load bookmarks', error: e, stackTrace: s);
        await prefs.remove('bookmarks');
      }
    }
  }

  Future<void> _saveBookmarks() async {
    if (widget.privateBrowsing) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bookmarks', bookmarkManager.save());
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
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Bookmark'),
        content: TextField(
          onChanged: (value) => category = value.isEmpty ? 'General' : value,
          decoration: const InputDecoration(labelText: 'Category'),
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
      }
    } on PlatformException {
      // Ignore MissingPluginException on macOS
    }
  }

  Future<void> _goForward() async {
    try {
      if (await activeTab.webViewController?.canGoForward() ?? false) {
        await activeTab.webViewController?.goForward();
      }
    } on PlatformException {
      // Ignore MissingPluginException on macOS
    }
  }

  Future<void> _refresh() async {
    try {
      await activeTab.webViewController?.reload();
    } on PlatformException {
      // Ignore MissingPluginException on macOS
    }
  }

  void _showBookmarks() {
    if (widget.privateBrowsing) {
      showDialog(
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
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bookmarks'),
        content: StatefulBuilder(
          builder: (context, innerSetState) => bookmarkManager.bookmarks.isEmpty
              ? const Text('No bookmarks')
              : SizedBox(
                  width: double.maxFinite,
                  height: 300,
                  child: ListView(
                    children: bookmarkManager.bookmarks.entries
                        .map((entry) => ExpansionTile(
                              title: Text(entry.key),
                              children: entry.value
                                  .map((url) => ListTile(
                                        title: Text(url),
                                        onTap: () {
                                          Navigator.of(context).pop();
                                          _loadUrl(url);
                                        },
                                        trailing: IconButton(
                                          icon: const Icon(Icons.delete),
                                          onPressed: () async {
                                            final confirm =
                                                await showDialog<bool>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text(
                                                    'Delete Bookmark?'),
                                                content: Text(
                                                    'Remove "$url" from ${entry.key}?'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.of(context)
                                                            .pop(false),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.of(context)
                                                            .pop(true),
                                                    child: const Text('Delete'),
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
    } catch (e, s) {
      logger.w('Failed to clear caches', error: e, stackTrace: s);
    }
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => SettingsDialog(
          onSettingsChanged: widget.onSettingsChanged,
          onClearCaches: _clearAllCaches,
          currentTheme: widget.themeMode,
          aiAvailable: widget.aiAvailable),
    );
  }

  void _showNetworkDebug() {
    showDialog(
      context: context,
      builder: (context) => const NetworkDebugDialog(),
    );
  }

  void _handleMenuSelection(String value) {
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
      case 'git_fetch':
        _showGitFetchDialog();
        break;
      case 'network_debug':
        _showNetworkDebug();
        break;
    }
  }

  List<PopupMenuEntry<String>> _buildMenuEntries() {
    return [
      const PopupMenuItem(
        value: 'add_bookmark',
        child: Row(
          children: [
            Icon(Icons.bookmark_add),
            SizedBox(width: 12),
            Text('Add Bookmark'),
          ],
        ),
      ),
      const PopupMenuItem(
        value: 'view_bookmarks',
        child: Row(
          children: [
            Icon(Icons.bookmarks),
            SizedBox(width: 12),
            Text('Bookmarks'),
          ],
        ),
      ),
      const PopupMenuItem(
        value: 'history',
        child: Row(
          children: [
            Icon(Icons.history),
            SizedBox(width: 12),
            Text('History'),
          ],
        ),
      ),
      if (widget.enableGitFetch)
        const PopupMenuItem(
          value: 'git_fetch',
          child: Row(
            children: [
              Icon(Icons.code),
              SizedBox(width: 12),
              Text('Git Fetch'),
            ],
          ),
        ),
      if (widget.aiAvailable)
        const PopupMenuItem(
          value: 'ai_chat',
          child: Row(
            children: [
              Icon(Icons.smart_toy),
              SizedBox(width: 12),
              Text('AI Chat'),
            ],
          ),
        ),
      const PopupMenuItem(
        value: 'settings',
        child: Row(
          children: [
            Icon(Icons.settings),
            SizedBox(width: 12),
            Text('Settings'),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'network_debug',
        child: Row(
          children: [
            Icon(Icons.network_check),
            SizedBox(width: 12),
            Text('Network Debug'),
          ],
        ),
      ),
    ];
  }

  PopupMenuButton<String> _buildMenuButton({double iconSize = 24}) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, size: iconSize),
      onSelected: _handleMenuSelection,
      itemBuilder: (context) => _buildMenuEntries(),
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
          } on PlatformException {
            // Ignore MissingPluginException on macOS
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
    showDialog(
      context: context,
      builder: (context) =>
          AiChatWidget(pageTitle: pageTitle, pageUrl: pageUrl),
    );
  }

  void _showHistory() {
    if (widget.privateBrowsing) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('History'),
          content: const Text('History is not saved in private browsing mode'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }
    final history = activeTab.history;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('History'),
        content: history.isEmpty
            ? const Text('No history')
            : SizedBox(
                width: double.maxFinite,
                height: 300,
                child: ListView.builder(
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final historyIndex = history.length - 1 - index;
                    return ListTile(
                      title: Text(history[historyIndex]),
                      onTap: () {
                        Navigator.of(context).pop();
                        _loadUrl(history[historyIndex]);
                      },
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          setState(() {
                            history.removeAt(historyIndex);
                          });
                        },
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
              });
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
  }

  Future<void> _loadUrl(String url) async {
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
    activeTab.urlController.text = processedUrl;
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
    } on PlatformException {
      // Ignore MissingPluginException on macOS
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
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.security,
                    size: 44,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Search Torry',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Private search via torry.io.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.outline.withValues(alpha: 0.6),
                    ),
                  ),
                  child: TextField(
                    controller: tab.torrySearchController,
                    focusNode: tab.torrySearchFocusNode,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (s) => _performTorrySearch(tab, s),
                    decoration: InputDecoration(
                      hintText: 'Search Torry',
                      border: InputBorder.none,
                      prefixIcon: Icon(
                        Icons.search,
                        color: colorScheme.primary,
                      ),
                      suffixIcon: IconButton(
                        onPressed: () => _performTorrySearch(tab),
                        icon: Icon(
                          Icons.arrow_forward,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: () =>
                          _loadUrl('https://www.torry.io/learn/directory/'),
                      icon: const Icon(Icons.list),
                      label: const Text('Onion directory'),
                    ),
                    TextButton.icon(
                      onPressed: () =>
                          _loadUrl('https://www.torry.io/anonymous-view/'),
                      icon: const Icon(Icons.visibility),
                      label: const Text('Anonymous view'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView(TabData tab) {
    final errorMessage = tab.state is BrowserError
        ? (tab.state as BrowserError).message
        : 'We could not load that page.';
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.public_off,
                size: 54,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Browser',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Sorry, we can’t open this page.',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                if (tab.webViewController != null)
                  FilledButton.icon(
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
                  onPressed: () {
                    tab.urlFocusNode.requestFocus();
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
      tab.webViewController!
          .setUserAgent(_getUserAgent(widget.useModernUserAgent));
      // Note: webview_flutter does not support built-in private browsing.
      // Cache is not stored for private tabs (LOAD_NO_CACHE equivalent not available).
      // Cookies are shared globally; private browsing does not clear them.
      // This is a limitation compared to flutter_inappwebview.
      // Partial workaround for SPA history: listen for popstate events via JS.
      tab.webViewController!.addJavaScriptChannel('HistoryChannel',
          onMessageReceived: (JavaScriptMessage message) {
        final url = message.message;
        if (!widget.privateBrowsing && !tab.history.contains(url)) {
          tab.history.add(url);
          if (tab.history.length > 50) {
            tab.history.removeAt(0);
          }
        }
        // Update the URL bar for SPA navigation
        if (!tab.isClosed && mounted && tab.currentUrl != url) {
          setState(() {
            tab.currentUrl = url;
            tab.urlController.text = url;
          });
        }
        _updateThemeFromTab(tab);
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
                if (!widget.privateBrowsing &&
                    (tab.history.isEmpty ||
                        tab.history.last != tab.currentUrl)) {
                  tab.history.add(tab.currentUrl);
                  if (tab.history.length > 50) {
                    tab.history.removeAt(0);
                  }
                }
              });
            }
          }
        },
        onPageFinished: (url) {
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
          ''');
            // Inject login detection script
            tab.webViewController!.runJavaScript(loginDetectionScript);
            // Attempt autofill if credentials available
            _attemptAutofill(tab);
          }
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
      try {
        tab.webViewController!.loadRequest(Uri.parse(tab.currentUrl));
      } on FormatException {
        logger.w('Invalid URL: ${tab.currentUrl}');
        _handleLoadError(tab, 'Invalid URL format');
      } on PlatformException {
        // Ignore MissingPluginException on macOS
      }
    }

    try {
      return KeepAliveWrapper(
        child: Stack(
          children: [
            WebViewWidget(controller: tab.webViewController!),
            if (tab.state is Loading)
              Container(
                color: Theme.of(context)
                    .colorScheme
                    .surface
                    .withValues(alpha: 0.8),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const _TelescopeLoader(),
                      const SizedBox(height: 16),
                      Text(
                        'Searching...',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (tab.pendingPasswordPrompt != null &&
                activeTab == tab)
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
    final double titleBarInset =
        defaultTargetPlatform == TargetPlatform.macOS ? _titleBarHeight : 0.0;
    final leadingInset =
        defaultTargetPlatform == TargetPlatform.macOS ? 88.0 : 16.0;

    final PreferredSizeWidget? appBarWidget = widget.hideAppBar
        ? null
        : AppBar(
            actions: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, size: 18),
                      onPressed: _goBack,
                      tooltip: 'Back',
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios, size: 18),
                      onPressed: _goForward,
                      tooltip: 'Forward',
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _addNewTab,
                tooltip: 'New Tab',
              ),
              _buildMenuButton(),
            ],
            title: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  SizedBox(width: leadingInset),
                  Icon(
                    Icons.search,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: activeTab.urlController,
                      focusNode: activeTab.urlFocusNode,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search or enter URL',
                        hintStyle: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onSubmitted: _loadUrl,
                    ),
                  ),
                  if (activeTab.state is Loading)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    )
                  else
                    IconButton(
                      icon: Icon(
                        Icons.refresh,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                      onPressed: _refresh,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ),
          );

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          final isCommandOrControl = (isCommandKey && HardwareKeyboard.instance.isMetaPressed) ||
              (isControlKey && HardwareKeyboard.instance.isControlPressed);

          if (isCommandOrControl) {
            if (event.logicalKey == LogicalKeyboardKey.keyT) {
              _addNewTab();
            } else if (event.logicalKey == LogicalKeyboardKey.keyW) {
              _closeTab(tabController.index);
            } else if (event.logicalKey == LogicalKeyboardKey.keyL) {
              activeTab.urlFocusNode.requestFocus();
            } else if (event.logicalKey == LogicalKeyboardKey.keyR) {
              _refresh();
            }
          } else if (HardwareKeyboard.instance.isAltPressed) {
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              _goBack();
            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              _goForward();
            }
          }
        }
      },
      child: Shortcuts(
      shortcuts: {
        SingleActivator(LogicalKeyboardKey.keyL,
                control: isControlKey,
                meta: isCommandKey):
            FocusUrlIntent(),
        SingleActivator(LogicalKeyboardKey.keyR,
                control: isControlKey,
                meta: isCommandKey):
            RefreshIntent(),
        SingleActivator(LogicalKeyboardKey.keyT,
                control: isControlKey,
                meta: isCommandKey):
            NewTabIntent(),
        SingleActivator(LogicalKeyboardKey.keyW,
                control: isControlKey,
                meta: isCommandKey):
            CloseTabIntent(),
        SingleActivator(LogicalKeyboardKey.keyN,
                control: isControlKey,
                meta: isCommandKey):
            NewWindowIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true):
            GoBackIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true):
            GoForwardIntent(),
      },
      child: FocusableActionDetector(
        autofocus: true,
        shortcuts: const {},
        actions: const {},
        child: Actions(
        actions: {
          FocusUrlIntent: CallbackAction<FocusUrlIntent>(
            onInvoke: (intent) => activeTab.urlFocusNode.requestFocus(),
          ),
          RefreshIntent: CallbackAction<RefreshIntent>(
            onInvoke: (intent) => _refresh(),
          ),
          NewTabIntent: CallbackAction<NewTabIntent>(
            onInvoke: (intent) => _addNewTab(),
          ),
          CloseTabIntent: CallbackAction<CloseTabIntent>(
            onInvoke: (intent) => _closeTab(tabController.index),
          ),
          NewWindowIntent: CallbackAction<NewWindowIntent>(
            onInvoke: (intent) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('New window not supported in desktop app'),
                  duration: Duration(seconds: 2),
                ),
              );
              return null;
            },
          ),
          GoBackIntent: CallbackAction<GoBackIntent>(
            onInvoke: (intent) => _goBack(),
          ),
          GoForwardIntent: CallbackAction<GoForwardIntent>(
            onInvoke: (intent) => _goForward(),
          ),
        },
        child: DropTarget(
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
            appBar: titleBarInset > 0 && appBarWidget != null
                ? PreferredSize(
                    preferredSize:
                        Size.fromHeight(kToolbarHeight + titleBarInset),
                    child: Column(
                      children: [
                        Container(
                          height: titleBarInset,
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
                      child: TabBar(
                        controller: tabController,
                        isScrollable: true,
                        indicatorColor: widget.themeMode == AppThemeMode.adjust
                            ? Colors.transparent
                            : Theme.of(context).colorScheme.primary,
                        dividerColor: widget.themeMode == AppThemeMode.adjust
                            ? Colors.transparent
                            : Theme.of(context)
                                .colorScheme
                                .outline
                                .withValues(alpha: 0.2),
                        labelColor: Theme.of(context).colorScheme.onSurface,
                        unselectedLabelColor: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                        tabs: tabs.asMap().entries.map((entry) {
                          final index = entry.key;
                          final tab = entry.value;
                          return Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.public,
                                  size: 16,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.7),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  (Uri.tryParse(tab.currentUrl)?.host ??
                                          tab.currentUrl)
                                      .truncate(15),
                                ),
                                if (tabs.length > 1) ...[
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => _closeTab(index),
                                    child: Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: tabController,
                        children:
                            tabs.map((tab) => _buildTabBody(tab)).toList(),
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
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios, size: 18),
                            onPressed: _goBack,
                            tooltip: 'Back',
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward_ios, size: 18),
                            onPressed: _goForward,
                            tooltip: 'Forward',
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh, size: 18),
                            onPressed: _refresh,
                            tooltip: 'Refresh',
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, size: 18),
                            onPressed: _addNewTab,
                            tooltip: 'New Tab',
                          ),
                          IconButton(
                            icon: const Icon(Icons.settings, size: 18),
                            onPressed: _showSettings,
                            tooltip: 'Settings',
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
              ],
            ),
          ),
        ),
      ),
    ),
    ),
    );
  }
}
