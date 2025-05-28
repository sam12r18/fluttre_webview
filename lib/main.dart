import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

Timer? _locationTimer;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final WebViewController _controller;
  final String baseUrl = 'https://damcheck.ir';

  @override
  void initState() {
    super.initState();
    _initWebView();

   // _initLocationTracking(); // شروع بررسی موقعیت مکانی
  }

  Future<void> _initWebView() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString('session_id');

    final PlatformWebViewControllerCreationParams params =
        const PlatformWebViewControllerCreationParams();

    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) async {
            final cookieString = await _controller.runJavaScriptReturningResult("document.cookie");
            print('🍪 Cookies: $cookieString');

            final localStorage = await _controller.runJavaScriptReturningResult("JSON.stringify(localStorage)");
            final sessionStorage =await _controller.runJavaScriptReturningResult("JSON.stringify(sessionStorage)");

            print('📦 localStorage: $localStorage');
            print('📦 sessionStorage: $sessionStorage');

            final prefs = await SharedPreferences.getInstance();
             // استخراج location_enabled از localStorage (یا sessionStorage اگر نیاز داری)
            final locationEnabledValue = await _controller.runJavaScriptReturningResult("localStorage.getItem('location_enabled')");
            // await _controller.runJavaScriptReturningResult("sessionStorage.getItem('location_enabled')=='1'?alert('Location Enabled') : alert('Location Disabled');");

            // پاک‌سازی مقدار از رشته JSON و بررسی true/false
            final cleaned = locationEnabledValue.toString().replaceAll('"', '').toLowerCase();
            final isEnabled = cleaned == 'true';

            await prefs.setBool('location_enabled', isEnabled);
            print('🔧 تنظیم location_enabled: $isEnabled');


            final jwtTokenResult = await _controller.runJavaScriptReturningResult("localStorage.getItem('token')");
            // حذف " و تبدیل به رشته
            final jwtToken = jwtTokenResult.toString().replaceAll('"', '');
            await prefs.setString('jwtToken', jwtToken);
            print('🔑 JWT Token: $jwtToken');

            // شروع موقعیت‌یابی اگر فعال بود
            if (isEnabled) {
              _initLocationTracking();
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(baseUrl));

    if (_controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
    }

    if (sessionId != null) {
      final cookieManager = WebViewCookieManager();
      await cookieManager.setCookie(
        WebViewCookie(
          name: 'session_id',
          value: sessionId,
          domain: 'damcheck.ir',
          path: '/',
        ),
      );
    }

    setState(() {});
  }

  // دریافت موقعیت مکانی و ارسال آن به سرور
  Future<void> _initLocationTracking() async {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool('location_enabled') ?? false;

    if (!isEnabled) return;

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }

    if (!serviceEnabled ||
        permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      print('❌ دسترسی به موقعیت غیرفعال است.');
      return;
    }

    _locationTimer = Timer.periodic(Duration(minutes: 1), (_) async {
      Position position = await Geolocator.getCurrentPosition();
      final lat = position.latitude;
      final lng = position.longitude;

      final sessionId = prefs.getString('session_id');
      final jwtToken = prefs.getString('jwtToken');

      if (sessionId != null) {
        try {
          final response = await http.post(
            Uri.parse('https://your-api.com/location'),
            headers: {
              'Authorization': 'Bearer $jwtToken',
              'Content-Type': 'application/x-www-form-urlencoded', // اگر با فرم‌داده ارسال می‌کنی
          },
            body: {
              'lat': lat.toString(),
              'lng': lng.toString(),
              'session_id': sessionId,
            },
          );
          print('📡 لوکیشن ارسال شد: $lat, $lng');
        } catch (e) {
          print('⚠️ خطا در ارسال لوکیشن: $e');
        }
      }
    });
  
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        // appBar: AppBar(title: const Text('Flutter WebView')),
        body: _controller == null
            ? const Center(child: CircularProgressIndicator())
            : WebViewWidget(controller: _controller),
      ),
    );
  }
}
