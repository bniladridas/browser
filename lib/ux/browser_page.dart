// SPDX-License-Identifier: MIT
//
// Copyright 2025 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class FocusUrlIntent extends Intent {}

class RefreshIntent extends Intent {}

class GoBackIntent extends Intent {}

class GoForwardIntent extends Intent {}

class BrowserPage extends StatefulWidget {
  const BrowserPage({super.key, required this.initialUrl});

  final String initialUrl;

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  static const String _searchUrl = 'https://www.google.com/search?q=';

  final TextEditingController urlController = TextEditingController();
  final FocusNode urlFocusNode = FocusNode();
  InAppWebViewController? webViewController;
  late String currentUrl;
  bool isLoading = false;
  bool hasError = false;
  String? errorMessage;
  final List<String> bookmarks = [];

  @override
  void initState() {
    super.initState();
    currentUrl = widget.initialUrl;
    urlController.text = currentUrl;
    _loadBookmarks();
  }

  @override
  void dispose() {
    urlController.dispose();
    urlFocusNode.dispose();
    _saveBookmarks();
    super.dispose();
  }



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

  void _showSettings() {
    final homepageController = TextEditingController(text: widget.initialUrl);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: homepageController,
              decoration: const InputDecoration(labelText: 'Homepage'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('homepage', homepageController.text);
              Navigator.of(context).pop();
              // Optionally, reload or notify
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _goBack() async {
    if (await webViewController?.canGoBack() ?? false) {
      await webViewController?.goBack();
    }
  }

  Future<void> _goForward() async {
    if (await webViewController?.canGoForward() ?? false) {
      await webViewController?.goForward();
    }
  }

  Future<void> _refresh() async {
    await webViewController?.reload();
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

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text('Failed to load page.', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                hasError = false;
              });
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (hasError) {
      return _buildErrorView();
    }

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
                    hasError = false;
                    errorMessage = null;
                  });
                }
              }
            },
            onLoadStop: (controller, url) {
              if (mounted) {
                setState(() {
                  isLoading = false;
                });
              }
            },
            onReceivedError: (controller, request, error) {
              if (mounted) {
                setState(() {
                  hasError = true;
                  errorMessage = error.description;
                  isLoading = false;
                });
              }
            },
            onReceivedHttpError: (controller, request, error) {
              if (mounted) {
                setState(() {
                  hasError = true;
                  errorMessage = 'HTTP ${error.statusCode}: ${error.reasonPhrase}';
                  isLoading = false;
                });
              }
            },
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
    return Shortcuts(
      shortcuts: {
        SingleActivator(LogicalKeyboardKey.keyL, control: defaultTargetPlatform != TargetPlatform.macOS, meta: defaultTargetPlatform == TargetPlatform.macOS): FocusUrlIntent(),
        SingleActivator(LogicalKeyboardKey.keyR, control: defaultTargetPlatform != TargetPlatform.macOS, meta: defaultTargetPlatform == TargetPlatform.macOS): RefreshIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): GoBackIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true): GoForwardIntent(),
      },
      child: Actions(
        actions: {
          FocusUrlIntent: CallbackAction<FocusUrlIntent>(
            onInvoke: (intent) => urlFocusNode.requestFocus(),
          ),
          RefreshIntent: CallbackAction<RefreshIntent>(
            onInvoke: (intent) => _refresh(),
          ),
          GoBackIntent: CallbackAction<GoBackIntent>(
            onInvoke: (intent) => _goBack(),
          ),
          GoForwardIntent: CallbackAction<GoForwardIntent>(
            onInvoke: (intent) => _goForward(),
          ),
        },
        child: Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _goBack,
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: _goForward,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_add),
            onPressed: _addBookmark,
          ),
           IconButton(
             icon: const Icon(Icons.bookmarks),
             onPressed: _showBookmarks,
           ),
           IconButton(
             icon: const Icon(Icons.settings),
             onPressed: _showSettings,
           ),
        ],
        title: Row(
          children: [
            Expanded(
              child: TextField(
                controller: urlController,
                focusNode: urlFocusNode,
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
    ),
  ),
);
}
}
