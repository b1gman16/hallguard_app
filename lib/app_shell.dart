import 'package:flutter/material.dart';
import 'pages/home/home_page.dart';
import 'pages/alerts/alerts_page.dart';
import 'pages/system/system_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  void _goToSystemTab() {
    setState(() => _currentIndex = 2);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(onOpenSystem: _goToSystemTab),
      const AlertsPage(),
      const SystemPage(),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.warning_amber_rounded),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_input_component_rounded),
            label: 'System',
          ),
        ],
      ),
    );
  }
}