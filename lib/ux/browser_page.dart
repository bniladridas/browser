// SPDX-License-Identifier: MIT
//
// Copyright 2025 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class BrowserPage extends StatefulWidget {
  const BrowserPage({super.key});

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  static const String _initialUrl = 'https://www.google.com';

  final TextEditingController urlController = TextEditingController();
  InAppWebViewController? webViewController;
  late String currentUrl;
  final List<String> bookmarks = [];

  @override
  void initState() {
    super.initState();
    currentUrl = _initialUrl;
    urlController.text = currentUrl;
  }

  @override
  void dispose() {
    urlController.dispose();
    super.dispose();
  }

  void _addBookmark() {
    if (!bookmarks.contains(currentUrl)) {
      setState(() {
        bookmarks.add(currentUrl);
      });
    }
  }

  void _showBookmarks() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bookmarks'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            itemCount: bookmarks.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(bookmarks[index]),
                onTap: () {
                  Navigator.of(context).pop();
                  if (index < bookmarks.length) {
                    _loadUrl(bookmarks[index]);
                  }
                },
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    setState(() {
                      if (index < bookmarks.length) {
                        bookmarks.removeAt(index);
                      }
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
                bookmarks.clear();
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
    } catch (e, s) {
      debugPrint('Error creating InAppWebView: $e\n$s');
      return const Center(
        child: Text('Failed to load browser.'),
      );
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
          IconButton(
            icon: const Icon(Icons.bookmark_add),
            onPressed: _addBookmark,
          ),
          IconButton(
            icon: const Icon(Icons.bookmarks),
            onPressed: _showBookmarks,
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
