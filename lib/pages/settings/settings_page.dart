import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
          children: [
            Text('Settings', style: text.headlineSmall?.copyWith(fontSize: 26)),
            const SizedBox(height: 4),
            Text('Preferences and system information', style: text.bodyMedium),
            const SizedBox(height: 20),

            Text('Notifications', style: text.titleLarge),
            const SizedBox(height: 12),

            const _SettingsTile(
              icon: Icons.notifications_active_rounded,
              title: 'Alert Notifications',
              subtitle: 'Receive unsafe event alerts on this device',
              trailing: _StaticSwitch(value: true),
            ),
            const SizedBox(height: 12),
            const _SettingsTile(
              icon: Icons.volume_up_rounded,
              title: 'Alert Sound',
              subtitle: 'Play a sound when unsafe activity is detected',
              trailing: _StaticSwitch(value: true),
            ),
            const SizedBox(height: 12),
            const _SettingsTile(
              icon: Icons.vibration_rounded,
              title: 'Vibration',
              subtitle: 'Vibrate on important alert updates',
              trailing: _StaticSwitch(value: true),
            ),

            const SizedBox(height: 24),

            Text('Appearance', style: text.titleLarge),
            const SizedBox(height: 12),

            const _SettingsTile(
              icon: Icons.dark_mode_rounded,
              title: 'Theme',
              subtitle: 'HallGuard dark mode is currently active',
              trailingText: 'Dark',
            ),
            const SizedBox(height: 12),
            const _SettingsTile(
              icon: Icons.dashboard_customize_rounded,
              title: 'Dashboard Style',
              subtitle: 'Use the command-center layout for monitoring',
              trailingText: 'Active',
            ),

            const SizedBox(height: 24),

            Text('System', style: text.titleLarge),
            const SizedBox(height: 12),

            const _SettingsTile(
              icon: Icons.cloud_done_rounded,
              title: 'Firebase Connection',
              subtitle: 'Connected to live event and status data',
              trailingText: 'Online',
              trailingColor: AppColors.success,
            ),
            const SizedBox(height: 12),
            const _SettingsTile(
              icon: Icons.security_rounded,
              title: 'Monitoring Mode',
              subtitle: 'Unsafe event detection and alerting are enabled',
              trailingText: 'Enabled',
              trailingColor: AppColors.primary,
            ),
            const SizedBox(height: 12),
            const _SettingsTile(
              icon: Icons.admin_panel_settings_rounded,
              title: 'Admin Access',
              subtitle: 'Administrative monitoring dashboard available',
              trailingText: 'Granted',
              trailingColor: AppColors.warning,
            ),

            const SizedBox(height: 24),

            Text('About', style: text.titleLarge),
            const SizedBox(height: 12),

            const _SettingsTile(
              icon: Icons.info_outline_rounded,
              title: 'App Version',
              subtitle: 'HallGuard mobile monitoring application',
              trailingText: 'v1.0.0',
            ),
            const SizedBox(height: 12),
            const _SettingsTile(
              icon: Icons.memory_rounded,
              title: 'System Role',
              subtitle: 'Real-time hallway safety monitoring and alert review',
              trailingText: 'Mobile Console',
            ),

            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.stroke),
              ),
              child: Text(
                'This settings screen is intentionally lightweight. It gives the app a complete product structure without adding unnecessary controls that are outside the current HallGuard scope.',
                style: text.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final String? trailingText;
  final Color? trailingColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.trailingText,
    this.trailingColor,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleMedium),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: text.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (trailing != null)
            trailing!
          else if (trailingText != null)
            Text(
              trailingText!,
              style: text.labelLarge?.copyWith(
                color: trailingColor ?? AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _StaticSwitch extends StatelessWidget {
  final bool value;

  const _StaticSwitch({required this.value});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Switch(
        value: value,
        onChanged: (_) {},
        activeThumbColor: Colors.white,
        activeTrackColor: AppColors.primary,
        inactiveThumbColor: AppColors.textSecondary,
        inactiveTrackColor: AppColors.stroke,
      ),
    );
  }
}
