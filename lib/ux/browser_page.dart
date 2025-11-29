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

class UrlUtils {
  static String processUrl(String url) {
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
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
  bool _hideAppBar = false;

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
      _hideAppBar = prefs.getBool(hideAppBarKey) ?? false;
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
           SwitchListTile(
             title: const Text('Hide App Bar'),
             value: _hideAppBar,
             onChanged: (value) {
               setState(() {
                 _hideAppBar = value;
               });
             },
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
               await prefs.setBool(hideAppBarKey, _hideAppBar);
               widget.onSettingsChanged?.call();
               if (mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(content: Text('Settings saved')),
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

class TabData {
  String currentUrl;
  final TextEditingController urlController;
  final FocusNode urlFocusNode;
  InAppWebViewController? webViewController;
  bool isLoading = false;
  bool hasError = false;
  String? errorMessage;
  final List<String> history = [];
  bool isClosed = false;

  TabData(this.currentUrl)
      : urlController = TextEditingController(text: currentUrl),
        urlFocusNode = FocusNode();
}

class BrowserPage extends StatefulWidget {
  const BrowserPage({super.key, required this.initialUrl, this.hideAppBar = false, this.onSettingsChanged});

  final String initialUrl;
  final bool hideAppBar;
  final void Function()? onSettingsChanged;

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> with TickerProviderStateMixin {
  late TabController tabController;
  final List<TabData> tabs = [];
  final List<String> bookmarks = [];

  @override
  void initState() {
    super.initState();
    tabs.add(TabData(widget.initialUrl));
    tabController = TabController(length: 1, vsync: this);
    tabController.addListener(_onTabChanged);
    _loadBookmarks();
  }

  void _onTabChanged() {
    setState(() {});
  }

  TabData get activeTab => tabs[tabController.index];

  void _addNewTab() {
    setState(() {
      tabs.add(TabData('https://www.google.com'));
      tabController.dispose(); // Dispose the old controller to prevent memory leaks.
      tabController = TabController(length: tabs.length, vsync: this, initialIndex: tabs.length - 1);
      tabController.addListener(_onTabChanged);
    });
  }

  void _closeTab(int index) {
    if (tabs.length > 1) {
      setState(() {
        tabs[index].isClosed = true;
        tabs[index].urlController.dispose();
        tabs[index].urlFocusNode.dispose();
        tabs.removeAt(index);

        // Determine the new index before disposing the old controller.
        int newIndex = tabController.index;
        if (newIndex >= tabs.length) {
          newIndex = tabs.length - 1;
        }

        // Dispose the old controller and create a new one.
        tabController.dispose();
        tabController = TabController(length: tabs.length, vsync: this, initialIndex: newIndex);
        tabController.addListener(_onTabChanged);
      });
    }
  }

  @override
  void dispose() {
    for (final tab in tabs) {
      tab.urlController.dispose();
      tab.urlFocusNode.dispose();
    }
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

  void _handleLoadError(TabData tab, String newErrorMessage) {
    if (mounted) {
      setState(() {
        tab.hasError = true;
        tab.errorMessage = newErrorMessage;
        tab.isLoading = false;
        tab.webViewController = null;
      });
    }
  }

  void _addBookmark() async {
    if (!bookmarks.contains(activeTab.currentUrl)) {
      setState(() {
        bookmarks.add(activeTab.currentUrl);
      });
      await _saveBookmarks();
    }
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
    } catch (e) {
      // Ignore MissingPluginException on macOS
    }
  }

  Future<void> _refresh() async {
    try {
      await activeTab.webViewController?.reload();
    } catch (e) {
      // Ignore MissingPluginException on macOS
    }
  }

  void _showBookmarks() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bookmarks'),
        content: bookmarks.isEmpty
            ? const Text('No bookmarks')
            : SizedBox(
                width: double.maxFinite,
                height: 300, // Fixed height for test
                child: ListView.builder(
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
                              title: const Text('Remove Bookmark?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: const Text('Remove'),
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

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => SettingsDialog(onSettingsChanged: widget.onSettingsChanged),
    );
  }

  void _showHistory() {
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

  void _loadUrl(String url) {
    url = UrlUtils.processUrl(url);
    activeTab.currentUrl = url;
    activeTab.urlController.text = url;
    try {
      activeTab.webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
    } catch (e) {
      // Ignore MissingPluginException on macOS
    }
  }

  Widget _buildErrorView(TabData tab) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error, size: 48, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 12),
          Text('Page failed to load.', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              setState(() {
                tab.hasError = false;
                tab.errorMessage = null;
              });
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBody(TabData tab) {
    if (tab.hasError) {
      return _buildErrorView(tab);
    }

    try {
      return Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(tab.currentUrl)),
            initialSettings: InAppWebViewSettings(
              cacheEnabled: true,
              clearCache: false,
              useOnLoadResource: false,
            ),
            onWebViewCreated: (controller) {
              tab.webViewController = controller;
            },
            onLoadStart: (controller, url) {
              if (url != null && !tab.isClosed) {
                setState(() {
                  tab.currentUrl = url.toString();
                  tab.urlController.text = tab.currentUrl;
                  tab.isLoading = true;
                  tab.hasError = false;
                  tab.errorMessage = null;
                  if (tab.history.isEmpty || tab.history.last != tab.currentUrl) {
                    tab.history.add(tab.currentUrl);
                  }
                });
              }
            },
            onLoadStop: (controller, url) {
              if (mounted) {
                setState(() {
                  tab.isLoading = false;
                });
              }
            },
            onReceivedError: (controller, request, error) {
              _handleLoadError(tab, error.description);
            },
            onReceivedHttpError: (controller, request, error) {
              _handleLoadError(tab, 'HTTP ${error.statusCode}: ${error.reasonPhrase}');
            },
          ),
          if (tab.isLoading)
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
             onInvoke: (intent) => activeTab.urlFocusNode.requestFocus(),
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
       appBar: widget.hideAppBar ? null : AppBar(
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
           PopupMenuButton<String>(
             onSelected: (value) {
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
                 case 'settings':
                   _showSettings();
                   break;
                 case 'new_tab':
                   _addNewTab();
                   break;
                 case 'close_tab':
                   _closeTab(tabController.index);
                   break;
               }
             },
             itemBuilder: (context) => [
               const PopupMenuItem(
                 value: 'new_tab',
                 child: Text('New Tab'),
               ),
               if (tabs.length > 1)
                 const PopupMenuItem(
                   value: 'close_tab',
                   child: Text('Close Tab'),
                 ),
               const PopupMenuItem(
                 value: 'add_bookmark',
                 child: Text('Add Bookmark'),
               ),
               const PopupMenuItem(
                 value: 'view_bookmarks',
                 child: Text('Bookmarks'),
               ),
               const PopupMenuItem(
                 value: 'history',
                 child: Text('History'),
               ),
               const PopupMenuItem(
                 value: 'settings',
                 child: Text('Settings'),
               ),
             ],
           ),
         ],
         title: Row(
           children: [
             Expanded(
               child: TextField(
                 controller: activeTab.urlController,
                 focusNode: activeTab.urlFocusNode,
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
       body: Stack(
         children: [
           Column(
             children: [
               TabBar(
                 controller: tabController,
                 isScrollable: true,
                 tabs: tabs.map((tab) => Tab(text: Uri.tryParse(tab.currentUrl)?.host ?? tab.currentUrl)).toList(),
               ),
               Expanded(
                 child: TabBarView(
                   controller: tabController,
                   children: tabs.map((tab) => _buildTabBody(tab)).toList(),
                 ),
               ),
             ],
           ),
           if (widget.hideAppBar)
             Positioned(
               top: 10,
               right: 10,
               child: FloatingActionButton(
                 mini: true,
                 onPressed: _showSettings,
                 child: const Icon(Icons.settings),
               ),
             ),
         ],
       ),
    ),
  ),
);
}
}
