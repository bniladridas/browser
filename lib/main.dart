// SPDX-License-Identifier: MIT
//
// Copyright 2025 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'logging/logger.dart';
import 'features/theme_utils.dart';
import 'ux/browser_page.dart';
import 'package:pkg/ai_service.dart';
import 'constants.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  AppThemeMode themeMode = AppThemeMode.system;
  String homepage = 'https://www.google.com';
  bool hideAppBar = false;
  bool useModernUserAgent = false;
  bool enableGitFetch = false;
  bool privateBrowsing = false;
  bool adBlocking = false;
  bool strictMode = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        homepage = prefs.getString(homepageKey) ?? 'https://www.google.com';
        hideAppBar = prefs.getBool(hideAppBarKey) ?? false;
        useModernUserAgent = prefs.getBool(useModernUserAgentKey) ?? false;
        enableGitFetch = prefs.getBool(enableGitFetchKey) ?? false;
        privateBrowsing = prefs.getBool(privateBrowsingKey) ?? false;
        adBlocking = prefs.getBool(adBlockingKey) ?? false;
        strictMode = prefs.getBool(strictModeKey) ?? false;
        final themeString = prefs.getString(themeModeKey);
        if (themeString != null) {
          themeMode = AppThemeMode.values.firstWhere(
            (m) => m.name == themeString,
            orElse: () => AppThemeMode.system,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
        themeMode: toThemeMode(themeMode),
        home: BrowserPage(
          initialUrl: homepage,
          hideAppBar: hideAppBar,
          useModernUserAgent: useModernUserAgent,
          enableGitFetch: enableGitFetch,
          privateBrowsing: privateBrowsing,
          adBlocking: adBlocking,
          strictMode: strictMode,
          themeMode: themeMode,
          onSettingsChanged: _loadSettings,
        ),
      ),
    );
  }
}

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await dotenv.load();
    } catch (e) {
      logger.w(
          'Warning: .env file not found. Firebase keys will use defaults. $e');
    }
    try {
      await windowManager.ensureInitialized();
    } catch (e) {
      logger.w(
          'Warning: Window manager initialization failed on this platform: $e. Some desktop window features (minimize, maximize, etc.) may not be available.');
    }
    try {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
      AiService().initialize();
    } catch (e) {
      logger.w(
          'Firebase initialization failed: $e. AI features will not be available.');
    }
    runApp(const MyApp());
  }, (error, stack) {
    logger.e('Uncaught error: $error', error: error, stackTrace: stack);
  });
}
