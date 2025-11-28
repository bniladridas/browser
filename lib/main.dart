// SPDX-License-Identifier: MIT
//
// Copyright 2025 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'package:window_manager/window_manager.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Browser',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const BrowserPage(),
    );
  }
}

class BrowserPage extends StatefulWidget {
  const BrowserPage({super.key});

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  final TextEditingController urlController = TextEditingController();
  InAppWebViewController? webViewController;
  String currentUrl = 'https://www.google.com';

  @override
  void initState() {
    super.initState();
    urlController.text = currentUrl;
  }



  void _loadUrl(String url) {
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    urlController.text = url;
    webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
  }

  Widget _buildBody() {
    try {
      return InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(currentUrl)),
        onWebViewCreated: (controller) {
          webViewController = controller;
        },
        onLoadStart: (controller, url) {
          if (url != null) {
            setState(() {
              currentUrl = url.toString();
              urlController.text = currentUrl;
            });
          }
        },
      );
    } catch (e) {
      return Container();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (await webViewController?.canGoBack() ?? false) {
                await webViewController?.goBack();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: () async {
              if (await webViewController?.canGoForward() ?? false) {
                await webViewController?.goForward();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await webViewController?.reload();
            },
          ),
        ],
        title: Row(
          children: [
            Expanded(
              child: TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  hintText: 'Enter URL',
                  border: InputBorder.none,
                ),
                onSubmitted: _loadUrl,
              ),
            ),
          ],
        ),
      ),
       body: _buildBody(),
    );
  }
}
