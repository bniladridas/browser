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
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;

import '../constants.dart';
import '../features/theme_utils.dart';
import '../features/bookmark_manager.dart';

import '../features/video_manager.dart';
import '../logging/logger.dart';

const String _modernUserAgent =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0.2 Safari/605.1.15';
const String _legacyUserAgent =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/50.0.0.0 Safari/537.36';

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

  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    const ellipsis = '...';
    if (maxLength <= ellipsis.length) return text.substring(0, maxLength);
    return '${text.substring(0, maxLength - ellipsis.length)}$ellipsis';
  }
}

class SettingsDialog extends StatefulWidget {
  const SettingsDialog(
      {super.key,
      this.onSettingsChanged,
      this.onClearCaches,
      this.currentTheme});

  final void Function()? onSettingsChanged;
  final void Function()? onClearCaches;
  final AppThemeMode? currentTheme;

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late TextEditingController homepageController;
  String? currentHomepage;
  bool _hideAppBar = false;
  bool _useModernUserAgent = false;
  bool _enableGitFetch = false;
  bool _privateBrowsing = false;
  bool _adBlocking = false;
  bool _strictMode = false;
  AppThemeMode _selectedTheme = AppThemeMode.system;

  @override
  void initState() {
    super.initState();
    _selectedTheme = widget.currentTheme ?? AppThemeMode.system;
    _loadCurrentHomepage();
  }

  Future<void> _loadCurrentHomepage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentHomepage =
          prefs.getString(homepageKey) ?? 'https://www.google.com';
      homepageController = TextEditingController(text: currentHomepage);
      _hideAppBar = prefs.getBool(hideAppBarKey) ?? false;
      _useModernUserAgent = prefs.getBool(useModernUserAgentKey) ?? false;
      _enableGitFetch = prefs.getBool(enableGitFetchKey) ?? false;
      _privateBrowsing = prefs.getBool(privateBrowsingKey) ?? false;
      _adBlocking = prefs.getBool(adBlockingKey) ?? false;
      _strictMode = prefs.getBool(strictModeKey) ?? false;
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
      content: SingleChildScrollView(
        child: Column(
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
            SwitchListTile(
              title: const Text('Use Modern User Agent'),
              subtitle: const Text(
                  'Load modern Google interface (applies to new tabs)'),
              value: _useModernUserAgent,
              onChanged: (value) {
                setState(() {
                  _useModernUserAgent = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Enable Git Fetch'),
              subtitle:
                  const Text('Show GitHub repository fetch option in menu'),
              value: _enableGitFetch,
              onChanged: (value) {
                setState(() {
                  _enableGitFetch = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Private Browsing'),
              subtitle: const Text('Disable cache and cookies for privacy'),
              value: _privateBrowsing,
              onChanged: (value) {
                setState(() {
                  _privateBrowsing = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Ad Blocking'),
              subtitle: const Text('Block common ad domains'),
              value: _adBlocking,
              onChanged: (value) {
                setState(() {
                  _adBlocking = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Strict Mode'),
              subtitle:
                  const Text('Disable JavaScript and third-party cookies'),
              value: _strictMode,
              onChanged: (value) {
                setState(() {
                  _strictMode = value;
                });
              },
            ),
            DropdownButton<AppThemeMode>(
              value: _selectedTheme,
              onChanged: (AppThemeMode? value) {
                if (value != null) {
                  setState(() {
                    _selectedTheme = value;
                  });
                }
              },
              items: AppThemeMode.values
                  .map<DropdownMenuItem<AppThemeMode>>((AppThemeMode mode) {
                return DropdownMenuItem<AppThemeMode>(
                  value: mode,
                  child: Text('Theme: ${mode.name}'),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            final homepage = homepageController.text.trim();
            if (Uri.tryParse(homepage)?.hasScheme != true) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invalid homepage URL')),
              );
              return;
            }
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(homepageKey, homepage);
            await prefs.setBool(hideAppBarKey, _hideAppBar);
            await prefs.setBool(useModernUserAgentKey, _useModernUserAgent);
            await prefs.setBool(enableGitFetchKey, _enableGitFetch);
            await prefs.setBool(privateBrowsingKey, _privateBrowsing);
            await prefs.setBool(adBlockingKey, _adBlocking);
            await prefs.setBool(strictModeKey, _strictMode);
            await prefs.setString(themeModeKey, _selectedTheme.name);

            widget.onSettingsChanged?.call();
            widget.onClearCaches?.call();
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
  WebViewController? webViewController;
  bool isLoading = false;
  bool hasError = false;
  String? errorMessage;
  final List<String> history = [];
  bool isClosed = false;

  TabData(this.currentUrl)
      : urlController = TextEditingController(text: currentUrl),
        urlFocusNode = FocusNode();
}

class GitFetchDialog extends StatefulWidget {
  const GitFetchDialog({super.key, required this.onOpenInNewTab});

  final void Function(String url) onOpenInNewTab;

  @override
  State<GitFetchDialog> createState() => _GitFetchDialogState();
}

class _GitFetchDialogState extends State<GitFetchDialog> {
  final TextEditingController repoController = TextEditingController();
  bool isLoading = false;
  Map<String, dynamic>? repoData;
  String? errorMessage;

  Future<void> _fetchRepo() async {
    final repo = repoController.text.trim();
    if (repo.isEmpty) return;

    final parts = repo.split('/');
    if (parts.length != 2) {
      setState(() {
        errorMessage = 'Invalid format. Use owner/repo';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
      repoData = null;
    });

    try {
      final url = 'https://api.github.com/repos/${parts[0]}/${parts[1]}';
      // Note: This would use webfetch tool in the assistant, but in code we use http
      // For demo, using placeholder
      final response = await fetchGitHubRepo(url);
      if (mounted) {
        setState(() {
          repoData = response;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = 'Failed to fetch repo: $e';
          isLoading = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>> fetchGitHubRepo(String url) async {
    final response =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load repo: ${response.statusCode}');
    }
  }

  @override
  void dispose() {
    repoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Git Fetch'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: repoController,
            decoration: const InputDecoration(
              labelText: 'GitHub Repo (owner/repo)',
              hintText: 'e.g., flutter/flutter',
            ),
          ),
          const SizedBox(height: 16),
          if (isLoading) const CircularProgressIndicator(),
          if (errorMessage != null)
            Text(errorMessage!, style: const TextStyle(color: Colors.red)),
          if (repoData != null) ...[
            Text('Name: ${repoData!['name'] ?? 'N/A'}'),
            Text(
                'Description: ${repoData!['description'] ?? 'No description'}'),
            Text('Stars: ${repoData!['stargazers_count'] ?? 0}'),
            Text('Forks: ${repoData!['forks_count'] ?? 0}'),
            Text('Language: ${repoData!['language'] ?? 'N/A'}'),
            Text('Open Issues: ${repoData!['open_issues_count'] ?? 0}'),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _fetchRepo,
          child: const Text('Fetch'),
        ),
        if (repoData != null)
          TextButton(
            onPressed: () {
              final url = 'https://github.com/${repoController.text}';
              widget.onOpenInNewTab(url);
              Navigator.of(context).pop();
            },
            child: const Text('Open in New Tab'),
          ),
      ],
    );
  }
}

class BrowserPage extends StatefulWidget {
  const BrowserPage(
      {super.key,
      required this.initialUrl,
      this.hideAppBar = false,
      this.useModernUserAgent = false,
      this.enableGitFetch = false,
      this.privateBrowsing = false,
      this.adBlocking = false,
      this.strictMode = false,
      this.themeMode = AppThemeMode.system,
      this.onSettingsChanged});

  final String initialUrl;
  final bool hideAppBar;
  final bool useModernUserAgent;
  final bool enableGitFetch;
  final bool privateBrowsing;
  final bool adBlocking;
  final bool strictMode;
  final AppThemeMode themeMode;
  final void Function()? onSettingsChanged;

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class KeepAliveWrapper extends StatefulWidget {
  final Widget child;

  const KeepAliveWrapper({super.key, required this.child});

  @override
  State<KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _BrowserPageState extends State<BrowserPage>
    with TickerProviderStateMixin {
  late TabController tabController;
  final List<TabData> tabs = [];
  final bookmarkManager = BookmarkManager();
  late int previousTabIndex;
  List<RegExp> adBlockerPatterns = [];

  @override
  void initState() {
    super.initState();
    tabs.add(TabData(widget.initialUrl));
    tabController = TabController(length: 1, vsync: this);
    previousTabIndex = 0;
    tabController.addListener(_onTabChanged);
    _loadBookmarks();
    if (widget.adBlocking) {
      loadAdBlockers();
    }
  }

  Future<void> loadAdBlockers() async {
    try {
      final jsonString = await rootBundle.loadString('assets/ad_blockers.json');
      final List<dynamic> rules = jsonDecode(jsonString);
      adBlockerPatterns =
          rules.map((rule) => RegExp(rule['urlFilter'])).toList();
    } catch (e) {
      logger.w('Failed to load or compile ad blockers: $e');
    }
  }

  void _onTabChanged() {
    if (previousTabIndex != tabController.index) {
      // Pause videos on previous tab
      final prevTab = tabs[previousTabIndex];
      if (prevTab.webViewController != null) {
        VideoManager.pauseVideos(prevTab.webViewController!);
      }
      // Resume videos on current tab
      final currTab = tabs[tabController.index];
      if (currTab.webViewController != null) {
        VideoManager.resumeVideos(currTab.webViewController!);
      }
    }
    previousTabIndex = tabController.index;
    if (mounted) {
      setState(() {});
    }
  }

  TabData get activeTab => tabs[tabController.index];

  void _addNewTab() {
    if (mounted) {
      setState(() {
        tabs.add(TabData('https://www.google.com'));
        tabController
            .dispose(); // Dispose the old controller to prevent memory leaks.
        tabController = TabController(
            length: tabs.length, vsync: this, initialIndex: tabs.length - 1);
        tabController.addListener(_onTabChanged);
      });
      previousTabIndex = tabController.index;
    }
  }

  void _closeTab(int index) {
    if (tabs.length > 1) {
      setState(() {
        tabs[index].isClosed = true;
        tabs[index].urlController.dispose();
        tabs[index].urlFocusNode.dispose();
        tabs.removeAt(index);

        // Clear cache and cookies for private browsing
        if (widget.privateBrowsing) {
          _clearAllCaches();
        }

        // Determine the new index before disposing the old controller.
        int newIndex = tabController.index;
        if (newIndex >= tabs.length) {
          newIndex = tabs.length - 1;
        }

        // Dispose the old controller and create a new one.
        tabController.dispose();
        tabController = TabController(
            length: tabs.length, vsync: this, initialIndex: newIndex);
        tabController.addListener(_onTabChanged);
      });
      previousTabIndex = tabController.index;
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
      bookmarkManager.load(bookmarksJson);
    }
  }

  Future<void> _saveBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bookmarks', bookmarkManager.save());
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
    String category = 'General';
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Bookmark'),
        content: TextField(
          onChanged: (value) => category = value.isEmpty ? 'General' : value,
          decoration: const InputDecoration(labelText: 'Category'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              bookmarkManager.add(activeTab.currentUrl, category);
              _saveBookmarks();
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
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
    } on PlatformException {
      // Ignore MissingPluginException on macOS
    }
  }

  Future<void> _refresh() async {
    try {
      await activeTab.webViewController?.reload();
    } on PlatformException {
      // Ignore MissingPluginException on macOS
    }
  }

  void _showBookmarks() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bookmarks'),
        content: StatefulBuilder(
          builder: (context, innerSetState) => bookmarkManager.bookmarks.isEmpty
              ? const Text('No bookmarks')
              : SizedBox(
                  width: double.maxFinite,
                  height: 300,
                  child: ListView(
                    children: bookmarkManager.bookmarks.entries
                        .map((entry) => ExpansionTile(
                              title: Text(entry.key),
                              children: entry.value
                                  .map((url) => ListTile(
                                        title: Text(url),
                                        onTap: () {
                                          Navigator.of(context).pop();
                                          _loadUrl(url);
                                        },
                                        trailing: IconButton(
                                          icon: const Icon(Icons.delete),
                                          onPressed: () async {
                                            final confirm =
                                                await showDialog<bool>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text(
                                                    'Delete Bookmark?'),
                                                content: Text(
                                                    'Remove "$url" from ${entry.key}?'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.of(context)
                                                            .pop(false),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.of(context)
                                                            .pop(true),
                                                    child: const Text('Delete'),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirm == true) {
                                              innerSetState(() {
                                                bookmarkManager.remove(
                                                    url, entry.key);
                                              });
                                              _saveBookmarks();
                                            }
                                          },
                                        ),
                                      ))
                                  .toList(),
                            ))
                        .toList(),
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                bookmarkManager.clear();
              });
              _saveBookmarks();
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

  Future<void> _clearAllCaches() async {
    final cookieManager = WebViewCookieManager();
    await cookieManager.clearCookies();
    for (final tab in tabs) {
      await tab.webViewController?.clearCache();
    }
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => SettingsDialog(
          onSettingsChanged: widget.onSettingsChanged,
          onClearCaches: _clearAllCaches,
          currentTheme: widget.themeMode),
    );
  }

  void _showGitFetchDialog() {
    showDialog(
      context: context,
      builder: (context) => GitFetchDialog(
        onOpenInNewTab: (url) {
          _addNewTab();
          activeTab.currentUrl = url;
          activeTab.urlController.text = url;
          activeTab.webViewController?.loadRequest(Uri.parse(url));
        },
      ),
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
      activeTab.webViewController?.loadRequest(Uri.parse(url));
    } on PlatformException {
      // Ignore MissingPluginException on macOS
    }
  }

  Widget _buildErrorView(TabData tab) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error,
              size: 48, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 12),
          Text('Page failed to load.',
              style: Theme.of(context).textTheme.headlineSmall),
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

    if (tab.webViewController == null) {
      tab.webViewController = WebViewController();
      tab.webViewController!.setJavaScriptMode(widget.strictMode
          ? JavaScriptMode.disabled
          : JavaScriptMode.unrestricted);
      tab.webViewController!.setUserAgent(
          widget.useModernUserAgent ? _modernUserAgent : _legacyUserAgent);
      // Note: webview_flutter does not support built-in private browsing.
      // Cache is not stored for private tabs (LOAD_NO_CACHE equivalent not available).
      // Cookies are shared globally; private browsing does not clear them.
      // This is a limitation compared to flutter_inappwebview.
      // Partial workaround for SPA history: listen for popstate events via JS.
      tab.webViewController!.addJavaScriptChannel('HistoryChannel',
          onMessageReceived: (JavaScriptMessage message) {
        final url = message.message;
        if (!tab.history.contains(url)) {
          tab.history.add(url);
          if (tab.history.length > 50) {
            tab.history.removeAt(0);
          }
        }
      });
      tab.webViewController!.setNavigationDelegate(NavigationDelegate(
        onPageStarted: (url) {
          if (!tab.isClosed) {
            if (mounted) {
              setState(() {
                tab.currentUrl = url;
                tab.urlController.text = tab.currentUrl;
                tab.isLoading = true;
                tab.hasError = false;
                tab.errorMessage = null;
                if (tab.history.isEmpty || tab.history.last != tab.currentUrl) {
                  tab.history.add(tab.currentUrl);
                  if (tab.history.length > 50) {
                    tab.history.removeAt(0);
                  }
                }
              });
            }
          }
        },
        onPageFinished: (url) {
          if (mounted) {
            setState(() {
              tab.isLoading = false;
            });
          }
          // Add listeners for SPA navigations: popstate, pushState, replaceState
          tab.webViewController!.runJavaScript('''
            if (!window.historyListenerAdded) {
              window.addEventListener('popstate', function(event) {
                HistoryChannel.postMessage(window.location.href);
              });
              // Override pushState and replaceState to capture programmatic changes
              window.originalPushState = window.history.pushState;
              window.history.pushState = function(state, title, url) {
                window.originalPushState.call(this, state, title, url);
                HistoryChannel.postMessage(window.location.href);
              };
              window.originalReplaceState = window.history.replaceState;
              window.history.replaceState = function(state, title, url) {
                window.originalReplaceState.call(this, state, title, url);
                HistoryChannel.postMessage(window.location.href);
              };
              window.historyListenerAdded = true;
            }
          ''');
        },
        onNavigationRequest: (request) {
          if (widget.adBlocking &&
              adBlockerPatterns
                  .any((pattern) => pattern.hasMatch(request.url.toString()))) {
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
        onWebResourceError: (error) {
          _handleLoadError(tab, error.description);
        },
        onHttpError: (error) {
          _handleLoadError(tab, 'HTTP ${error.response?.statusCode}');
        },
      ));
      tab.webViewController!.loadRequest(Uri.parse(tab.currentUrl));
    }

    try {
      return KeepAliveWrapper(
        child: Stack(
          children: [
            WebViewWidget(controller: tab.webViewController!),
            if (tab.isLoading)
              const Center(
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      );
    } catch (e, s) {
      logger.e('Error creating WebView: $e\n$s');
      return const Center(
        child: Text('Failed to load browser.'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        SingleActivator(LogicalKeyboardKey.keyL,
                control: defaultTargetPlatform != TargetPlatform.macOS,
                meta: defaultTargetPlatform == TargetPlatform.macOS):
            FocusUrlIntent(),
        SingleActivator(LogicalKeyboardKey.keyR,
                control: defaultTargetPlatform != TargetPlatform.macOS,
                meta: defaultTargetPlatform == TargetPlatform.macOS):
            RefreshIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true):
            GoBackIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true):
            GoForwardIntent(),
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
          appBar: widget.hideAppBar
              ? null
              : AppBar(
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

                          case 'git_fetch':
                            _showGitFetchDialog();
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
                        if (widget.enableGitFetch)
                          const PopupMenuItem(
                            value: 'git_fetch',
                            child: Text('Git Fetch'),
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
                    tabs: tabs
                        .map((tab) => Tab(
                            text: UrlUtils.truncate(
                                Uri.tryParse(tab.currentUrl)?.host ??
                                    tab.currentUrl,
                                20)))
                        .toList(),
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
