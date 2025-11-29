// SPDX-License-Identifier: MIT
//
// Copyright 2025 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class BrowserPage extends StatefulWidget {
  const BrowserPage({super.key});

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  static const String _initialUrl = 'https://www.google.com';
  static const String _searchUrl = 'https://www.google.com/search?q=';

  final TextEditingController urlController = TextEditingController();
  InAppWebViewController? webViewController;
  late String currentUrl;
  bool isLoading = false;
  final List<String> bookmarks = [];

  @override
  void initState() {
    super.initState();
    currentUrl = _initialUrl;
    urlController.text = currentUrl;
    _loadBookmarks();
  }

  @override
  void dispose() {
    urlController.dispose();
    _saveBookmarks();
    super.dispose();
  }

  void _hideLoadingIndicator() {
    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }
>>>>>>> 01b169e (feat: add loading indicator)
  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarksJson = prefs.getString('bookmarks');
    if (bookmarksJson != null) {
      setState(() {
        bookmarks.clear();
        bookmarks.addAll(List<String>.from(jsonDecode(bookmarksJson)));
      });
    }
  }

  Future<void> _saveBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bookmarks', jsonEncode(bookmarks));
  }

  void _addBookmark() async {
    if (!bookmarks.contains(currentUrl)) {
      setState(() {
        bookmarks.add(currentUrl);
      });
      await _saveBookmarks();
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
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Bookmark'),
                        content: const Text('Are you sure you want to delete this bookmark?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      setState(() {
                        if (index < bookmarks.length) {
                          bookmarks.removeAt(index);
                        }
                      });
                      await _saveBookmarks();
                    }
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              setState(() {
                bookmarks.clear();
              });
              await _saveBookmarks();
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
      // Check if it's a search query
      if (url.contains(' ') ||
          (!url.contains('.') &&
              !url.contains(':') &&
              url.toLowerCase() != 'localhost')) {
        url = _searchUrl + Uri.encodeComponent(url);
      } else {
        url = 'https://$url';
      }
    }
    urlController.text = url;
    webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
  }

  Widget _buildBody() {
    try {
      return Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(currentUrl)),
            onWebViewCreated: (controller) {
              webViewController = controller;
            },
            onLoadStart: (controller, url) {
              if (url != null) {
                if (mounted) {
                  setState(() {
                    currentUrl = url.toString();
                    urlController.text = currentUrl;
                    isLoading = true;
                  });
                }
              }
            },
            onLoadStop: (_, __) => _hideLoadingIndicator(),
            onReceivedError: (_, __, ___) => _hideLoadingIndicator(),
            onReceivedHttpError: (_, __, ___) => _hideLoadingIndicator(),
          ),
          if (isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
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
