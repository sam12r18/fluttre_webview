import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: FullscreenWebView(),
    );
  }
}

class FullscreenWebView extends StatefulWidget {
  const FullscreenWebView({Key? key}) : super(key: key);

  @override
  State<FullscreenWebView> createState() => _FullscreenWebViewState();
}

class _FullscreenWebViewState extends State<FullscreenWebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse('https://damcheck.ir')); // آدرس پیش‌فرض
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WebViewWidget(controller: _controller),
    );
  }
}
