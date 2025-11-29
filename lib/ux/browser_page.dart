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

import '../constants.dart';

class BrowserTab {
  String url;
  String title;
  InAppWebViewController? webViewController;
  bool isLoading;
  bool hasError;
  String? errorMessage;

  BrowserTab({
    required this.url,
    this.title = '',
    this.webViewController,
    this.isLoading = false,
    this.hasError = false,
    this.errorMessage,
  });
}

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key, this.onSettingsChanged});

  final void Function()? onSettingsChanged;

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late TextEditingController homepageController;
  String? currentHomepage;

  @override
  void initState() {
    super.initState();
    _loadCurrentHomepage();
  }

  Future<void> _loadCurrentHomepage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentHomepage = prefs.getString(homepageKey) ?? 'https://www.google.com';
      homepageController = TextEditingController(text: currentHomepage);
    });
  }

  @override
  void dispose() {
    homepageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (currentHomepage == null) {
      return const AlertDialog(
        title: Text('Settings'),
        content: CircularProgressIndicator(),
      );
    }

    return AlertDialog(
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
              await prefs.setString(homepageKey, homepageController.text);
              widget.onSettingsChanged?.call();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Homepage updated')),
                );
                Navigator.of(context).pop();
              }
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

class BrowserPage extends StatefulWidget {
  const BrowserPage({super.key, required this.initialUrl, this.onSettingsChanged});

  final String initialUrl;
  final void Function()? onSettingsChanged;

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> with TickerProviderStateMixin {
  static const String _searchUrl = 'https://www.google.com/search?q=';

  final TextEditingController urlController = TextEditingController();
  final FocusNode urlFocusNode = FocusNode();
  final List<BrowserTab> tabs = [];
  int currentTabIndex = 0;
  late TabController tabController;
  final List<String> bookmarks = [];
  final List<String> history = [];

  BrowserTab get currentTab => tabs[currentTabIndex];

  void _createNewTab({String url = 'https://www.google.com'}) {
    setState(() {
      tabs.add(BrowserTab(url: url));
      // Dispose the old controller to prevent memory leaks.
      tabController.dispose();
      tabController = TabController(length: tabs.length, vsync: this, initialIndex: tabs.length - 1);
      tabController.addListener(() {
        if (tabController.index != currentTabIndex) {
          _switchToTab(tabController.index);
        }
      });
      currentTabIndex = tabs.length - 1;
      urlController.text = url;
    });
  }

  void _closeTab(int index) {
    if (tabs.length == 1) return; // Don't close the last tab
    setState(() {
      // Dispose the old controller to prevent memory leaks.
      tabController.dispose();
      tabs.removeAt(index);

      if (currentTabIndex >= tabs.length) {
        currentTabIndex = tabs.length - 1;
      }

      // Create a new controller and re-add the listener.
      tabController = TabController(length: tabs.length, vsync: this, initialIndex: currentTabIndex);
      tabController.addListener(() {
        if (tabController.index != currentTabIndex) {
          _switchToTab(tabController.index);
        }
      });

      // Sync URL bar with the (potentially new) current tab
      urlController.text = currentTab.url;
    });
  }

  void _switchToTab(int index) {
    setState(() {
      currentTabIndex = index;
      tabController.index = index;
      urlController.text = currentTab.url;
    });
  }

  @override
  void initState() {
    super.initState();
    tabs.add(BrowserTab(url: widget.initialUrl));
    tabController = TabController(length: tabs.length, vsync: this);
    tabController.addListener(() {
      if (tabController.index != currentTabIndex) {
        _switchToTab(tabController.index);
      }
    });
    urlController.text = widget.initialUrl;
    _loadBookmarks();
  }

  @override
  void dispose() {
    urlController.dispose();
    urlFocusNode.dispose();
    tabController.dispose();
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

  void _handleLoadError(String newErrorMessage) {
    if (mounted) {
      setState(() {
        currentTab.hasError = true;
        currentTab.errorMessage = newErrorMessage;
        currentTab.isLoading = false;
        currentTab.webViewController = null;
      });
    }
  }

  void _addBookmark() async {
    if (!bookmarks.contains(currentTab.url)) {
      setState(() {
        bookmarks.add(currentTab.url);
      });
      await _saveBookmarks();
    }
  }

  Future<void> _goBack() async {
    if (await currentTab.webViewController?.canGoBack() ?? false) {
      await currentTab.webViewController?.goBack();
    }
  }

  Future<void> _goForward() async {
    if (await currentTab.webViewController?.canGoForward() ?? false) {
      await currentTab.webViewController?.goForward();
    }
  }

  Future<void> _refresh() async {
    await currentTab.webViewController?.reload();
  }

  void _showBookmarks() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bookmarks'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: bookmarks.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(bookmarks[index]),
                onTap: () {
                  Navigator.of(context).pop();
                  _loadUrl(bookmarks[index]);
                },
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Bookmark'),
                        content: Text('Remove ${bookmarks[index]}?'),
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
                        bookmarks.removeAt(index);
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

  void _showHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('History'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            itemCount: history.length,
            itemBuilder: (context, index) {
              final url = history[history.length - 1 - index];
              return ListTile(
                title: Text(url),
                onTap: () {
                  Navigator.of(context).pop();
                  _loadUrl(url);
                },
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    setState(() {
                      history.removeAt(history.length - 1 - index);
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
    setState(() {
      currentTab.url = url;
      urlController.text = url;
    });
    currentTab.webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
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
                currentTab.hasError = false;
                currentTab.errorMessage = null;
              });
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (currentTab.hasError) {
      return _buildErrorView();
    }

    try {
      return Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(currentTab.url)),
            onWebViewCreated: (controller) {
              currentTab.webViewController = controller;
            },
            onLoadStart: (controller, url) {
              if (url != null) {
                setState(() {
                  currentTab.url = url.toString();
                  urlController.text = currentTab.url;
                  currentTab.isLoading = true;
                  currentTab.hasError = false;
                  currentTab.errorMessage = null;
                  if (history.isEmpty || history.last != currentTab.url) {
                    history.add(currentTab.url);
                  }
                });
              }
            },
            onLoadStop: (controller, url) async {
              if (mounted) {
                final title = await controller.getTitle();
                setState(() {
                  currentTab.isLoading = false;
                  currentTab.title = title ?? '';
                });
              }
            },
            onReceivedError: (controller, request, error) {
              _handleLoadError(error.description);
            },
            onReceivedHttpError: (controller, request, error) {
              _handleLoadError('HTTP ${error.statusCode}: ${error.reasonPhrase}');
            },
          ),
          if (currentTab.isLoading)
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
        bottom: TabBar(
          controller: tabController,
          tabs: tabs.map((tab) {
            return Tab(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      tab.title.isNotEmpty ? tab.title : tab.url,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (tabs.length > 1)
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () => _closeTab(tabs.indexOf(tab)),
                    ),
                ],
              ),
            );
          }).toList(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _createNewTab,
          ),
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
             icon: const Icon(Icons.history),
             onPressed: _showHistory,
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
