// SPDX-License-Identifier: MIT
//
// Copyright 2025 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:window_manager/window_manager.dart';
import 'constants.dart';
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
  bool _prefsLoaded = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _initialUrl = prefs.getString(homepageKey) ?? 'https://www.google.com';
        _hideAppBar = prefs.getBool(hideAppBarKey) ?? false;
        _useModernUserAgent = prefs.getBool(useModernUserAgentKey) ?? false;
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
    final textTheme = Typography.dense2021.apply(fontFamily: 'Roboto');

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

    return MaterialApp(
      title: 'Browser',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        textTheme: textTheme,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue, brightness: Brightness.dark),
        textTheme: textTheme,
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: BrowserPage(
          initialUrl: _initialUrl,
          hideAppBar: _hideAppBar,
          useModernUserAgent: _useModernUserAgent,
          onSettingsChanged: _loadSettings),
    );
  }
}
