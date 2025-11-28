import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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
    _focusWindow();
  }

  void _focusWindow() async {
    await windowManager.focus();
  }

  void _loadUrl(String url) {
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () async {
              if (await webViewController?.canGoBack() ?? false) {
                await webViewController?.goBack();
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.arrow_forward),
            onPressed: () async {
              if (await webViewController?.canGoForward() ?? false) {
                await webViewController?.goForward();
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              webViewController?.reload();
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
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(currentUrl)),
        onWebViewCreated: (controller) {
          webViewController = controller;
        },
        onLoadStart: (controller, url) {
          setState(() {
            currentUrl = url.toString();
            urlController.text = currentUrl;
          });
        },
      ),
    );
  }
}
