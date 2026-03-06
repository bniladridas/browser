// SPDX-License-Identifier: MIT
//
// Copyright 2026 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'logging/logger.dart';
import 'features/theme_utils.dart';
import 'ux/browser_page.dart';
import 'package:pkg/ai_service.dart';
import 'constants.dart';

bool _isDuplicateKeyDownAssertion(FlutterErrorDetails details) {
  final message = details.exceptionAsString();
  return message.contains('A KeyDownEvent is dispatched') &&
      message.contains('physical key is already pressed') &&
      message.contains('hardware_keyboard.dart');
}

class MyApp extends StatefulWidget {
  const MyApp(
      {super.key, required this.aiAvailable, this.enableGitFetch = false});

  final bool aiAvailable;
  final bool enableGitFetch;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const String _whatsNewAssetPath = 'assets/whats_new.json';

  AppThemeMode themeMode = AppThemeMode.system;
  AppThemeMode? previewThemeMode;
  ThemeMode adjustedThemeMode = ThemeMode.system;
  Color adjustedSeedColor = Colors.blue;
  String homepage = defaultHomepageUrl;
  bool hideAppBar = false;
  bool useModernUserAgent = false;
  bool enableGitFetch = false;
  bool privateBrowsing = false;
  bool adBlocking = false;
  bool strictMode = false;
  String pageFontFamily = '';
  bool aiSearchSuggestionsEnabled = false;
  bool advancedCacheEnabled = false;
  bool _didCheckWhatsNew = false;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowWhatsNew();
    });
  }

  Future<void> _maybeShowWhatsNew() async {
    await _showWhatsNewDialog(ignoreSeenVersion: false);
  }

  Future<void> _showWhatsNewDialog({required bool ignoreSeenVersion}) async {
    if ((!ignoreSeenVersion && _didCheckWhatsNew) ||
        !mounted ||
        isIntegrationTest) {
      return;
    }
    if (!ignoreSeenVersion) {
      _didCheckWhatsNew = true;
    }
    final prefs = await SharedPreferences.getInstance();
    final info = await PackageInfo.fromPlatform();
    final currentVersion = info.version.trim();
    if (currentVersion.isEmpty) return;
    final seenVersion = prefs.getString(whatsNewSeenVersionKey);
    if (!ignoreSeenVersion && seenVersion == currentVersion) return;

    final notes = await _loadWhatsNewNotes(currentVersion);

    if (!mounted || _navigatorKey.currentContext == null) return;
    await showDialog<void>(
      context: _navigatorKey.currentContext!,
      barrierDismissible: false,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          title: Text(
            "What's New",
            style: theme.textTheme.titleSmall?.copyWith(fontSize: 15),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Version $currentVersion',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                ...notes.map(
                  (note) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '• $note',
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await prefs.setString(whatsNewSeenVersionKey, currentVersion);
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  Future<List<String>> _loadWhatsNewNotes(String version) async {
    try {
      final raw = await rootBundle.loadString(_whatsNewAssetPath);
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final entry = decoded[version];
        if (entry is List) {
          final notes = entry
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList(growable: false);
          if (notes.isNotEmpty) return notes;
        }
      }
    } catch (e, s) {
      logger.w(
        "Failed to load or parse What's New notes",
        error: e,
        stackTrace: s,
      );
    }
    return const <String>['Minor improvements and fixes.'];
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        final storedHomepage = prefs.getString(homepageKey);
        homepage = (storedHomepage == null || storedHomepage.isEmpty)
            ? defaultHomepageUrl
            : storedHomepage;
        hideAppBar = prefs.getBool(hideAppBarKey) ?? false;
        useModernUserAgent = prefs.getBool(useModernUserAgentKey) ?? false;
        enableGitFetch = prefs.getBool(enableGitFetchKey) ?? false;
        privateBrowsing = prefs.getBool(privateBrowsingKey) ?? false;
        adBlocking = prefs.getBool(adBlockingKey) ?? false;
        strictMode = prefs.getBool(strictModeKey) ?? false;
        pageFontFamily = prefs.getString(pageFontFamilyKey) ?? '';
        aiSearchSuggestionsEnabled =
            prefs.getBool(aiSearchSuggestionsEnabledKey) ?? false;
        advancedCacheEnabled = prefs.getBool(advancedCacheEnabledKey) ?? false;
        final themeString = prefs.getString(themeModeKey);
        if (themeString != null) {
          themeMode = AppThemeMode.values.firstWhere(
            (m) => m.name == themeString,
            orElse: () => AppThemeMode.system,
          );
        }
        previewThemeMode = null;
        if (themeMode != AppThemeMode.adjust) {
          adjustedThemeMode = ThemeMode.system;
          adjustedSeedColor = Colors.blue;
        }
      });
    }
  }

  void _setPreviewThemeMode(AppThemeMode mode) {
    if (!mounted) return;
    setState(() {
      previewThemeMode = mode;
      if (mode != AppThemeMode.adjust) {
        adjustedThemeMode = ThemeMode.system;
        adjustedSeedColor = Colors.blue;
      }
    });
  }

  void _clearPreviewThemeMode() {
    if (previewThemeMode == null || !mounted) return;
    setState(() {
      previewThemeMode = null;
      if (themeMode != AppThemeMode.adjust) {
        adjustedThemeMode = ThemeMode.system;
        adjustedSeedColor = Colors.blue;
      }
    });
  }

  void _setAdjustedThemeMode(ThemeMode mode, Color? seedColor) {
    final effectiveThemeMode = previewThemeMode ?? themeMode;
    if (effectiveThemeMode != AppThemeMode.adjust) return;
    final resolvedSeed = seedColor ?? Colors.blue;
    if (adjustedThemeMode == mode && adjustedSeedColor == resolvedSeed) {
      return;
    }
    void applyUpdate() {
      if (!mounted) return;
      setState(() {
        adjustedThemeMode = mode;
        adjustedSeedColor = resolvedSeed;
      });
    }

    final schedulerPhase = WidgetsBinding.instance.schedulerPhase;
    if (schedulerPhase == SchedulerPhase.persistentCallbacks ||
        schedulerPhase == SchedulerPhase.transientCallbacks ||
        schedulerPhase == SchedulerPhase.midFrameMicrotasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => applyUpdate());
    } else {
      applyUpdate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveThemeMode = previewThemeMode ?? themeMode;
    final resolvedThemeMode = effectiveThemeMode == AppThemeMode.adjust
        ? adjustedThemeMode
        : toThemeMode(effectiveThemeMode);
    final seedColor = effectiveThemeMode == AppThemeMode.adjust
        ? adjustedSeedColor
        : Colors.blue;
    final useAdjustedTheme = effectiveThemeMode == AppThemeMode.adjust;
    return ScaffoldMessenger(
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'Browser',
        debugShowCheckedModeBanner: false,
        theme: _buildThemeData(
          brightness: Brightness.light,
          seedColor: seedColor,
          useAdjustedTheme: useAdjustedTheme,
        ),
        darkTheme: _buildThemeData(
          brightness: Brightness.dark,
          seedColor: seedColor,
          useAdjustedTheme: useAdjustedTheme,
        ),
        themeMode: resolvedThemeMode,
        home: BrowserPage(
          initialUrl: homepage,
          hideAppBar: hideAppBar,
          useModernUserAgent: useModernUserAgent,
          enableGitFetch: widget.enableGitFetch || enableGitFetch,
          aiAvailable: widget.aiAvailable,
          privateBrowsing: privateBrowsing,
          adBlocking: adBlocking,
          strictMode: strictMode,
          pageFontFamily: pageFontFamily,
          aiSearchSuggestionsEnabled: aiSearchSuggestionsEnabled,
          advancedCacheEnabled: advancedCacheEnabled,
          themeMode: effectiveThemeMode,
          onPageThemeChanged: _setAdjustedThemeMode,
          onSettingsChanged: _loadSettings,
          onThemePreviewChanged: _setPreviewThemeMode,
          onThemePreviewReset: _clearPreviewThemeMode,
          onShowWhatsNew: () {
            _showWhatsNewDialog(ignoreSeenVersion: true);
          },
        ),
      ),
    );
  }

  ThemeData _buildThemeData({
    required Brightness brightness,
    required Color seedColor,
    required bool useAdjustedTheme,
  }) {
    var scheme =
        ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness);
    if (useAdjustedTheme) {
      final base = seedColor;
      final onBase =
          base.computeLuminance() < 0.5 ? Colors.white : Colors.black;
      scheme = scheme.copyWith(
        primary: base,
        onPrimary: onBase,
        surface: base,
        onSurface: onBase,
        onSurfaceVariant: onBase.withValues(alpha: 0.7),
        surfaceContainerHighest: _shiftSurface(base, 0.10),
        surfaceContainerHigh: _shiftSurface(base, 0.08),
        surfaceContainer: _shiftSurface(base, 0.06),
        surfaceContainerLow: _shiftSurface(base, 0.04),
        surfaceContainerLowest: _shiftSurface(base, 0.02),
        surfaceDim: _shiftSurface(base, -0.06),
        surfaceBright: _shiftSurface(base, 0.12),
        outline: onBase.withValues(alpha: 0.18),
      );
    }
    final hoverOnlyTransparentOverlay =
        WidgetStateProperty.resolveWith<Color?>((states) {
      return states.contains(WidgetState.hovered) ? Colors.transparent : null;
    });
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.onSurface,
        ).copyWith(overlayColor: hoverOnlyTransparentOverlay),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom()
            .copyWith(overlayColor: hoverOnlyTransparentOverlay),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom()
            .copyWith(overlayColor: hoverOnlyTransparentOverlay),
      ),
      switchTheme: SwitchThemeData(
        overlayColor: hoverOnlyTransparentOverlay,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        selectedColor: scheme.primaryContainer,
        disabledColor: scheme.surfaceContainerHighest,
        side: BorderSide.none,
        pressElevation: 0,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom()
            .copyWith(overlayColor: hoverOnlyTransparentOverlay),
      ),
    );
  }

  Color _shiftSurface(Color base, double amount) {
    final target = base.computeLuminance() < 0.5 ? Colors.white : Colors.black;
    final t = amount.abs().clamp(0.0, 1.0);
    if (amount < 0) {
      return Color.lerp(base, Colors.black, t) ?? base;
    }
    return Color.lerp(base, target, t) ?? base;
  }
}

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (kDebugMode &&
          defaultTargetPlatform == TargetPlatform.macOS &&
          _isDuplicateKeyDownAssertion(details)) {
        logger.w(
          'Ignoring known Flutter macOS duplicate KeyDown assertion: ${details.exceptionAsString()}',
        );
        return;
      }
      if (previousOnError != null) {
        previousOnError(details);
      } else {
        FlutterError.presentError(details);
      }
    };
    bool aiAvailable = false;
    try {
      await dotenv.load();
    } catch (e) {
      logger.w(
          'Warning: .env file not found. Firebase keys will use defaults. $e');
    }
    if (!isIntegrationTest) {
      try {
        await windowManager.ensureInitialized();
      } catch (e) {
        logger.w(
            'Warning: Window manager initialization failed on this platform: $e. Some desktop window features (minimize, maximize, etc.) may not be available.');
      }
    } else {
      logger.i('Skipping window manager initialization in integration mode.');
    }
    if (!isIntegrationTest) {
      try {
        await Firebase.initializeApp(
            options: await DefaultFirebaseOptions.currentPlatform);
        AiService().initialize();
        aiAvailable = true;
      } catch (e) {
        logger.w(
            'Firebase initialization failed: $e. AI features will not be available.');
      }
    } else {
      logger.i('Skipping Firebase/AI initialization in integration test mode.');
    }
    runApp(MyApp(aiAvailable: aiAvailable));
    if (defaultTargetPlatform == TargetPlatform.macOS && !isIntegrationTest) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await windowManager.waitUntilReadyToShow(
            const WindowOptions(
              titleBarStyle: TitleBarStyle.hidden,
              windowButtonVisibility: true,
            ),
            () {
              markWindowChromeReady();
              windowManager.show();
              windowManager.focus();
            },
          );
        } catch (e) {
          logger.w('Window ready callback failed: $e');
        }
      });
    }
  }, (error, stack) {
    logger.e('Uncaught error: $error', error: error, stackTrace: stack);
  });
}
