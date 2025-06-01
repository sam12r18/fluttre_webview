import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/verify_screen.dart';
import 'screens/mainwebview_screen.dart';
import 'theme/colors.dart';
import 'services/background_fetch_service.dart';
import 'services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تنظیمات نوار وضعیت و ناوبری
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
  //   statusBarColor: Colors.transparent,
  //   systemNavigationBarColor: Colors.white,
  //   statusBarIconBrightness: Brightness.dark,
  //   systemNavigationBarIconBrightness: Brightness.dark,
  // ));

  // Firebase پیام پوش
  // await Firebase.initializeApp();
  // await NotificationService.initialize();

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
    final url = message.data['url'] ?? 'https://damcheck.ir';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_url', url);
    navigatorKey.currentState?.pushReplacement(
      MaterialPageRoute(builder: (_) => const MainWebViewPage()),
    );
  });

  // سرویس پس‌زمینه
  BackgroundFetchService.initialize();
  BackgroundFetchService.registerPeriodicTask();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'DamCheck App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: GoogleFonts.vazirmatn().fontFamily,
        primarySwatch: customOrange,
        scaffoldBackgroundColor: Colors.white,
        textTheme: TextTheme(
          bodyMedium: TextStyle(fontSize: 16),
          titleLarge: TextStyle(fontWeight: FontWeight.bold),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
      home:  SplashScreen(),
      routes: {
        '/login': (_) =>  LoginScreen(),
        '/verify': (_) =>  VerifyScreen(),
        '/mainwebview': (_) =>  MainWebViewPage(),
      },
    );
  }
}
