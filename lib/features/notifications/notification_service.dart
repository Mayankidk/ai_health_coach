import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'dart:io';

class NotificationService {
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  
  // For Web/In-App notifications
  static final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

  Future<void> init({bool requestPermissions = true}) async {
    if (kIsWeb) return;
    
    // Initialize Timezone
    tz.initializeTimeZones();
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      if (kDebugMode) {
        print("NotificationService: Timezone initialized to $timeZoneName");
      }
    } catch (e) {
      if (kDebugMode) {
        print("NotificationService: Failed to get local timezone, defaulting to UTC: $e");
      }
      // Fallback is handled by initializeTimeZones() typically defaulting to UTC
    }
    
    const androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const initSettings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        if (kDebugMode) {
          print("Notification tapped: ${details.payload}");
        }
      },
    );

    // Request permissions for Android 13+ only if requested and not in background
    if (Platform.isAndroid && requestPermissions) {
      try {
        final androidImpl = _localNotifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
            
        await androidImpl?.requestNotificationsPermission();
        await androidImpl?.requestExactAlarmsPermission();
      } catch (e) {
        if (kDebugMode) {
          print("NotificationService: Error requesting permission: $e");
        }
      }
    }
  }

  Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    if (kIsWeb) return;

    if (kDebugMode) {
      print("NotificationService: Scheduling daily notification '$title' at $hour:$minute");
    }

    try {
      await _localNotifications.zonedSchedule(
        id,
        title,
        body,
        _nextInstanceOfTime(hour, minute),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_nudges',
            'Daily Nudges',
            channelDescription: 'Scheduled reminders and health tips',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      if (kDebugMode) {
        print("NotificationService: Failed to schedule daily notification: $e");
      }
      
      // Fallback to non-exact if exact fails
      if (e.toString().contains('exact_alarms_not_permitted')) {
        await _localNotifications.zonedSchedule(
          id,
          title,
          body,
          _nextInstanceOfTime(hour, minute),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'daily_nudges',
              'Daily Nudges',
              channelDescription: 'Scheduled reminders and health tips',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
    }
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  Future<void> cancelAll() async {
    await _localNotifications.cancelAll();
  }

  Future<void> showNudge(String title, String body) async {
    if (kIsWeb) {
      _showWebSnackbar(title, body);
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'immediate_nudges',
      'Immediate Nudges',
      channelDescription: 'One-off notifications',
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
