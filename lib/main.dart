import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'events_page_legacy.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const HallGuardApp());
}

class HallGuardApp extends StatelessWidget {
  const HallGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Colors.indigo;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'HallGuard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: colorScheme.surface,

        appBarTheme: AppBarTheme(
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.onSurface,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),

        // ✅ Use CardThemeData (your Flutter version expects this)
        cardTheme: CardThemeData(
          color: colorScheme.surface,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),

        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          labelStyle: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),

        dividerTheme: DividerThemeData(
          color: colorScheme.outlineVariant,
          thickness: 1,
          space: 1,
        ),

        textTheme: ThemeData.light().textTheme.copyWith(
          titleMedium: const TextStyle(fontWeight: FontWeight.w800),
          titleLarge: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      home: const EventsPage(),
    );
  }
}
