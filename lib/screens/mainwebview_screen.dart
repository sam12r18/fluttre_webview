import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';

// import 'package:open_file/open_file.dart';
import 'package:open_filex/open_filex.dart';

class MainWebViewPage extends StatefulWidget {
  final String? initialUrl;

  const MainWebViewPage({super.key, this.initialUrl});

  @override
  State<MainWebViewPage> createState() => _MainWebViewPageState();
}

class _MainWebViewPageState extends State<MainWebViewPage> {
  final String baseUrl = 'https://damcheck.ir';
  InAppWebViewController? _webViewController;
  PullToRefreshController? _pullToRefreshController;
  Timer? _locationTimer;
  bool _locationStarted = false;
  final GlobalKey webViewKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initLocationTracking();

    _pullToRefreshController = PullToRefreshController(
      onRefresh: () async {
        if (Platform.isAndroid) {
          _webViewController?.reload();
        } else if (Platform.isIOS) {
          Uri? url = await _webViewController?.getUrl();
          if (url != null) {
            _webViewController?.loadUrl(
                urlRequest: URLRequest(url: WebUri(url.toString())));
          }
        }
      },
    );
  }

  Future<void> _initLocationTracking() async {
    final prefs = await SharedPreferences.getInstance();
    final locationEnabled = prefs.getBool('location_enabled') ?? false;
    if (!locationEnabled || _locationStarted) return;

    _locationStarted = true;

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }

    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) return;

    _locationTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      try {
        Position position = await Geolocator.getCurrentPosition();
        final prefs = await SharedPreferences.getInstance();
        final jwt = prefs.getString('jwtToken');
        final sessionId = prefs.getString('session_id');

        if (jwt != null && sessionId != null) {
          await http.post(
            Uri.parse('https://your-api.com/location'),
            headers: {
              'Authorization': 'Bearer $jwt',
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: {
              'lat': position.latitude.toString(),
              'lng': position.longitude.toString(),
              'session_id': sessionId,
            },
          );
        }
      } catch (_) {
        print('🚫 خطا در ارسال لوکیشن');
      }
    });
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  // Future<bool> _onWillPop() async {
  //   if (await _controller.canGoBack()) {
  //     _controller.goBack();
  //     return false;
  //   }
  //   return true;
  // }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Scaffold(
      body: InAppWebView(
        key: webViewKey,
        initialUrlRequest:
            URLRequest(url: WebUri(widget.initialUrl ?? baseUrl)),
        initialOptions: InAppWebViewGroupOptions(
          crossPlatform: InAppWebViewOptions(
            javaScriptEnabled: true,
            useOnDownloadStart: true,
            mediaPlaybackRequiresUserGesture: false,
          ),
          android: AndroidInAppWebViewOptions(
            useHybridComposition: true,
            allowFileAccess: true,
          ),
          ios: IOSInAppWebViewOptions(
            allowsInlineMediaPlayback: true,
          ),
        ),
        pullToRefreshController: _pullToRefreshController,
        onWebViewCreated: (controller) async {
          _webViewController = controller;

          final prefs = await SharedPreferences.getInstance();
          final sessionId = prefs.getString('session_id');
          if (sessionId != null) {
            await CookieManager.instance().setCookie(
              url: WebUri(baseUrl),
              name: 'session_id',
              value: sessionId,
              path: '/',
            );
          }
        },
        onLoadStop: (controller, url) async {
          _pullToRefreshController?.endRefreshing();

          final prefs = await SharedPreferences.getInstance();

          final jwtToken = await controller.evaluateJavascript(
              source: "localStorage.getItem('token')");
          if (jwtToken != null && jwtToken != 'null') {
            await prefs.setString('jwtToken', jwtToken.replaceAll('"', ''));
          }

          final locationEnabled = await controller.evaluateJavascript(
              source: "localStorage.getItem('location_enabled')");
          final cleaned = locationEnabled?.toString().replaceAll('"', '') ?? '';
          await prefs.setBool('location_enabled', cleaned == 'true');

          _initLocationTracking();
        },
        onDownloadStartRequest: (controller, request) async {
          // درخواست همه مجوزها بر اساس نسخه اندروید
          if (Platform.isAndroid) {
            if (await Permission.storage.request().isGranted) {
              final url = request.url.toString();
              // final filename = request.suggestedFilename ?? "file_${DateTime
              //     .now()
              //     .millisecondsSinceEpoch}";

              // final dir = await getExternalStorageDirectory();
              // final filePath = '${dir?.path}/$filename';

              try {
                final downloadPath = await getDownloadPath();
                final filePath =
                    '$downloadPath/${request.suggestedFilename ?? "file.xls"}';
                await Dio().download(url, filePath);

                // await Dio().download(url, filePath);
                print("✅ محل ذخیره شدن فایل: $filePath");

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text("✅ فایل دانلود شد:"),
                        action: SnackBarAction(
                          label: 'باز کردن در $filePath',
                          onPressed: () {
                            OpenFilex.open(filePath);
                            // openDownloadedFile(filePath);
                          },
                        )),
                  );
                }
              } catch (e) {
                print("⛔ خطا در دانلود: $e");
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("⛔ خطا در دانلود فایل")),
                  );
                }
              }
            } else {
              print("❌ کاربر مجوز ذخیره‌سازی نداد.");
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("❌ دسترسی به حافظه رد شد")),
                );
              }
            }
          }
        },
        androidOnPermissionRequest: (InAppWebViewController controller,
            String origin, List<String> resources) async {
          return PermissionRequestResponse(
            resources: resources,
            action: PermissionRequestResponseAction.GRANT,
          );
        },
      ),
    ));
  }

  // void openDownloadedFile(String filePath) async {
  //   final result = await OpenFile.open(filePath);
  //   print("Open result: ${result.message}");
  // }

  Future<String?> getDownloadPath() async {
    if (await Permission.storage.request().isGranted) {
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (!(await directory.exists())) {
        await directory.create(recursive: true);
      }

      return directory.path;
    }
    return null;
  }
}
