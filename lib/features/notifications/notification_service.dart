import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  
  // For Web/In-App notifications
  static final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

  Future<void> init() async {
    if (kIsWeb) return;
    
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(initSettings);
  }

  Future<void> showNudge(String title, String body) async {
    if (kIsWeb) {
      _showWebSnackbar(title, body);
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'daily_nudges',
      'Daily Nudges',
      channelDescription: 'Reminders for workouts and habits',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      details,
    );
  }

  void _showWebSnackbar(String title, String body) {
    NotificationService.messengerKey.currentState?.clearSnackBars();
    NotificationService.messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(body),
          ],
        ),
        backgroundColor: Colors.teal.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        action: SnackBarAction(
          label: "OK",
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }
}
