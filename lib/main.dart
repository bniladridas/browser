// SPDX-License-Identifier: MIT
//
// Copyright 2025 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:window_manager/window_manager.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'constants.dart';
import 'features/ad_blockers.dart';
import 'features/theme_utils.dart';
import 'ux/browser_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await windowManager.ensureInitialized();
  } catch (e) {
    debugPrint(
        'Warning: Window manager initialization failed on this platform: $e. Some desktop window features (minimize, maximize, etc.) may not be available.');
  }
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _initialUrl = 'https://www.google.com';
  bool _hideAppBar = false;
  bool _useModernUserAgent = false;
  bool _enableGitFetch = false;
  bool _privateBrowsing = false;
  bool _adBlocking = false;
  bool _strictMode = false;
  AppThemeMode _themeMode = AppThemeMode.system;
  List<ContentBlocker> _adBlockers = [];
  bool _prefsLoaded = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _adBlockers = await getAdBlockers();
      setState(() {
        _initialUrl = prefs.getString(homepageKey) ?? 'https://www.google.com';
        _hideAppBar = prefs.getBool(hideAppBarKey) ?? false;
        _useModernUserAgent = prefs.getBool(useModernUserAgentKey) ?? false;
        _enableGitFetch = prefs.getBool(enableGitFetchKey) ?? false;
        _privateBrowsing = prefs.getBool(privateBrowsingKey) ?? false;
        _adBlocking = prefs.getBool(adBlockingKey) ?? false;
        _strictMode = prefs.getBool(strictModeKey) ?? false;
        dynamic themeValue = prefs.get(themeModeKey);
        String themeStr = themeValue is String ? themeValue : 'system';
        _themeMode = AppThemeMode.values.firstWhere((e) => e.name == themeStr,
            orElse: () => AppThemeMode.system);
      });
    } catch (e) {
      setState(() {
        _prefsLoaded = false;
      });
      debugPrint('Shared preferences not available: $e');
    }
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    if (!_prefsLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Settings could not be loaded. Using default values.')),
          );
          setState(() {
            _prefsLoaded = true;
          });
        }
      });
    }

    return ScaffoldMessenger(
      child: MaterialApp(
        title: 'Browser',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue, brightness: Brightness.dark),
          useMaterial3: true,
        ),
        themeMode: toThemeMode(_themeMode),
        home: BrowserPage(
            initialUrl: _initialUrl,
            hideAppBar: _hideAppBar,
            useModernUserAgent: _useModernUserAgent,
            enableGitFetch: _enableGitFetch,
            privateBrowsing: _privateBrowsing,
            adBlocking: _adBlocking,
            strictMode: _strictMode,
            adBlockers: _adBlockers,
            themeMode: _themeMode,
            onSettingsChanged: _loadSettings),
      ),
    );
  }
}
