import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'app_shell.dart';
import 'core/notifications/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Ensure local notifications are available in the background isolate.
  await NotificationService.initializeBackground();

  // For data-only messages, Android will not automatically display a notification.
  // Show one manually if the payload contains displayable content.
  await NotificationService.showBackgroundNotificationIfNeeded(message);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await NotificationService.initialize();

  runApp(const HallGuardApp());
}

class HallGuardApp extends StatelessWidget {
  const HallGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HallGuard',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const AppShell(),
    );
  }
}
