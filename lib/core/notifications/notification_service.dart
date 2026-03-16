import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'hallguard_alerts_channel',
    'HallGuard Alerts',
    description: 'Push notifications for unsafe hallway events',
    importance: Importance.max,
  );

  static Future<void> initialize() async {
    await _requestPermission();
    await _initializeLocalNotifications();
    await _initializeFirebaseMessaging();
  }

  static Future<void> _requestPermission() async {
    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(alert: true, badge: true, sound: true);

    await messaging.subscribeToTopic('hallguard_alerts');

    final token = await messaging.getToken();
    debugPrint('FCM TOKEN: $token');
  }

  static Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
    );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Tapped local notification payload: ${response.payload}');
      },
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(_channel);
  }

  static Future<void> _initializeFirebaseMessaging() async {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      await _showForegroundNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Notification opened app: ${message.data}');
    });

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('App opened from terminated state: ${initialMessage.data}');
    }
  }

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    final String title =
        message.notification?.title ?? message.data['title'] ?? 'HallGuard';

    final String body =
        message.notification?.body ??
        message.data['body'] ??
        'Unsafe event detected';

    final int notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await _localNotifications.show(
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'hallguard_alerts_channel',
          'HallGuard Alerts',
          channelDescription: 'Push notifications for unsafe hallway events',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }
}
