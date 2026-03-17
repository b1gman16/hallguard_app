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

  static bool _localNotificationsInitialized = false;
  static bool _firebaseListenersInitialized = false;

  static Future<void> initialize() async {
    await _requestPermission();
    await _initializeLocalNotifications();
    await _initializeFirebaseMessaging();
    await _logFcmToken();
  }

  static Future<void> initializeBackground() async {
    await _initializeLocalNotifications();
  }

  static Future<void> _requestPermission() async {
    final messaging = FirebaseMessaging.instance;

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint(
      'Notification permission status: ${settings.authorizationStatus}',
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      try {
        await messaging.subscribeToTopic('hallguard_alerts');
        debugPrint('Subscribed to topic: hallguard_alerts');
      } catch (e) {
        debugPrint('Failed to subscribe to topic: $e');
      }
    } else {
      debugPrint('Notifications not authorized; skipping topic subscription.');
    }
  }

  static Future<void> _logFcmToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      debugPrint('FCM TOKEN: $token');
    } catch (e) {
      debugPrint('Failed to get FCM token: $e');
    }
  }

  static Future<void> _initializeLocalNotifications() async {
    if (_localNotificationsInitialized) return;

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

    _localNotificationsInitialized = true;
  }

  static Future<void> _initializeFirebaseMessaging() async {
    if (_firebaseListenersInitialized) return;

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint(
        'FCM onMessage received. '
        'notification=${message.notification != null}, '
        'data=${message.data}',
      );

      await showFromRemoteMessage(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Notification opened app: ${message.data}');
    });

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('App opened from terminated state: ${initialMessage.data}');
    }

    _firebaseListenersInitialized = true;
  }

  static Future<void> showFromRemoteMessage(RemoteMessage message) async {
    await _initializeLocalNotifications();

    final title =
        message.notification?.title ??
        message.data['title']?.toString() ??
        'HallGuard';

    final body =
        message.notification?.body ??
        message.data['body']?.toString() ??
        'Unsafe event detected';

    final payload = message.data.isEmpty ? null : jsonEncode(message.data);

    await _localNotifications.show(
      id: _notificationIdFor(message),
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
      payload: payload,
    );
  }

  static Future<void> showBackgroundNotificationIfNeeded(
    RemoteMessage message,
  ) async {
    final hasNotificationPayload = message.notification != null;
    final hasDisplayableData =
        message.data['title'] != null || message.data['body'] != null;

    debugPrint(
      'FCM background message received. '
      'notification=$hasNotificationPayload, '
      'data=${message.data}',
    );

    if (!hasNotificationPayload && hasDisplayableData) {
      await showFromRemoteMessage(message);
    }
  }

  static int _notificationIdFor(RemoteMessage message) {
    final source =
        message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString();
    return source.hashCode & 0x7fffffff;
  }
}
