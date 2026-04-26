import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'app_shell.dart';
import 'core/notifications/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Background Firebase init failed: $e');
    return;
  }

  try {
    await NotificationService.initializeBackground();
    await NotificationService.showBackgroundNotificationIfNeeded(message);
  } catch (e) {
    debugPrint('Background notification handling failed: $e');
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StartupApp());
}

class StartupApp extends StatefulWidget {
  const StartupApp({super.key});

  @override
  State<StartupApp> createState() => _StartupAppState();
}

class _StartupAppState extends State<StartupApp> {
  late Future<bool> _startupFuture;

  @override
  void initState() {
    super.initState();
    _startupFuture = _initializeCore();
  }

  Future<bool> _initializeCore() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 8));

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      unawaited(_initializeNotificationsSafely());

      return true;
    } catch (e) {
      debugPrint('Startup Firebase init failed: $e');
      return false;
    }
  }

  Future<void> _initializeNotificationsSafely() async {
    try {
      await NotificationService.initialize().timeout(
        const Duration(seconds: 8),
      );
    } catch (e) {
      debugPrint('Notification initialization failed: $e');
    }
  }

  void _retry() {
    setState(() {
      _startupFuture = _initializeCore();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _startupFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _StartupFrame(
            child: _StartupLoadingView(),
          );
        }

        final firebaseReady = snapshot.data == true;

        return HallGuardApp(
          home: firebaseReady
              ? const AppShell()
              : _OfflineStartupPage(onRetry: _retry),
        );
      },
    );
  }
}

class HallGuardApp extends StatelessWidget {
  final Widget home;

  const HallGuardApp({
    super.key,
    required this.home,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HallGuard',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: home,
    );
  }
}

class _StartupFrame extends StatelessWidget {
  final Widget child;

  const _StartupFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HallGuard',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: child,
          ),
        ),
      ),
    );
  }
}

class _StartupLoadingView extends StatelessWidget {
  const _StartupLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_outlined, size: 72),
          SizedBox(height: 20),
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text(
            'Starting HallGuard...',
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'Loading core services.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _OfflineStartupPage extends StatelessWidget {
  final VoidCallback onRetry;

  const _OfflineStartupPage({
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 72),
                const SizedBox(height: 20),
                Text(
                  'HallGuard opened in offline startup mode',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'The app could not connect to Firebase during startup. '
                  'Please check the internet connection and try again.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry connection'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}