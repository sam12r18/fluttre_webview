import 'dart:convert';
import 'package:workmanager/workmanager.dart';
import 'package:http/http.dart' as http;
import 'notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const fetchBackground = "fetchBackground";

class BackgroundFetchService {
  static void initialize() {
    Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  }

  static void registerPeriodicTask() {
    Workmanager().registerPeriodicTask(
      "1",
      fetchBackground,
      frequency: const Duration(minutes: 15), // حداقل ۱۵ دقیقه در اندروید
    );
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {

    if (task == fetchBackground) {
      try {
        // دریافت توکن JWT از SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('jwtToken') ?? '';
        print('⚠️ ⛔تابع بک گراند فعال شد: ');

        if (token.isEmpty) {
          print('⛔توکن برای فعالیت بکگراند موجود نیست: ');
          // توکن موجود نیست، نمی‌توان درخواست زد
          return Future.value(true);
        }

        final url =
            Uri.parse('https://api.damcheck.ir/api/v2/check_notifications');

        final response = await http.get(
          url,
          headers: {
            'Authorization': 'Bearer $token',
          },
        );
        if (response.statusCode == 200) {
          List<dynamic> notifications = jsonDecode(response.body);

          if (notifications.isNotEmpty) {
            // برای هر اعلان یک نوتیفیکیشن جدا بساز یا فقط اولین اعلان را نشان بده
            for (var notification in notifications) {
              int id = notification['id'];
              String title = notification['title'] ?? 'پیام جدید';
              String subtitle = notification['subtitle'] ?? '';
              String details = notification['details'] ?? '';
              String url = notification['url'] ?? '';

              // داده‌ها را به صورت JSON رشته‌ای می‌کنیم تا موقع کلیک استفاده کنیم
              String payload = jsonEncode({
                'id': id,
                'url': url,
              });

              await NotificationService.showNotification(
                id: id,
                title: title,
                body: subtitle.isNotEmpty ? subtitle : details,
                payload: payload,
              );
            }
          }
        }
      } catch (e) {
        // خطاها را اینجا مدیریت کنید، مثلا لاگ بگیرید
        print('⚠️ خطا در فعاللیت بکگراند پیش آمده: $e');

      }
    }
    return Future.value(true);
  });
}
