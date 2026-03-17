import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class SystemPage extends StatefulWidget {
  const SystemPage({super.key});

  @override
  State<SystemPage> createState() => _SystemPageState();
}

class _SystemPageState extends State<SystemPage> {
  Timer? _ticker;

  Stream<DocumentSnapshot<Map<String, dynamic>>>? _statusStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _historyStream;
  Future<NotificationSettings>? _notificationSettingsFuture;

  @override
  void initState() {
    super.initState();

    _statusStream = FirebaseFirestore.instance
        .collection('status')
        .doc('current')
        .snapshots();

    _historyStream = FirebaseFirestore.instance
        .collection('events')
        .orderBy('client_time', descending: true)
        .limit(30)
        .snapshots();

    _notificationSettingsFuture = FirebaseMessaging.instance
        .getNotificationSettings();

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String timeAgoFromIso(String? iso) {
    if (iso == null || iso.isEmpty) return 'Unknown';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);

      if (diff.isNegative) return 'Just now';
      if (diff.inSeconds < 5) return 'Just now';
      if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return 'Unknown';
    }
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString());
  }

  String _cameraRatio(int? online, int? total) {
    if (online == null || total == null) return '--';
    return '$online/$total';
  }

  _StatusView _notificationStatus(NotificationSettings settings) {
    switch (settings.authorizationStatus) {
      case AuthorizationStatus.authorized:
        return const _StatusView(
          label: 'Allowed',
          subtitle: 'Notifications are enabled on this device',
          color: AppColors.success,
          icon: Icons.notifications_active_rounded,
        );
      case AuthorizationStatus.provisional:
        return const _StatusView(
          label: 'Provisional',
          subtitle: 'Notifications are partially allowed on this device',
          color: AppColors.warning,
          icon: Icons.notifications_rounded,
        );
      case AuthorizationStatus.denied:
        return const _StatusView(
          label: 'Blocked',
          subtitle: 'Notifications are blocked in device settings',
          color: AppColors.danger,
          icon: Icons.notifications_off_rounded,
        );
      case AuthorizationStatus.notDetermined:
        return const _StatusView(
          label: 'Not Set',
          subtitle: 'Notification permission has not been decided yet',
          color: AppColors.warning,
          icon: Icons.help_outline_rounded,
        );
    }
  }

  _StatusView _firebaseConnectionStatus(
    AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
  ) {
    if (snapshot.hasError) {
      return const _StatusView(
        label: 'Error',
        subtitle: 'Could not read the live system status document',
        color: AppColors.danger,
        icon: Icons.cloud_off_rounded,
      );
    }

    if (snapshot.connectionState == ConnectionState.waiting) {
      return const _StatusView(
        label: 'Checking',
        subtitle: 'Connecting to Firestore...',
        color: AppColors.warning,
        icon: Icons.cloud_sync_rounded,
      );
    }

    final data = snapshot.data?.data();
    if (data == null) {
      return const _StatusView(
        label: 'Unavailable',
        subtitle: 'No system status document was found',
        color: AppColors.warning,
        icon: Icons.cloud_off_rounded,
      );
    }

    return const _StatusView(
      label: 'Connected',
      subtitle: 'Live status data is being read successfully',
      color: AppColors.success,
      icon: Icons.cloud_done_rounded,
    );
  }

  _OverviewStatus _overviewStatus(Map<String, dynamic>? data) {
    if (data == null) {
      return const _OverviewStatus(
        value: 'Unavailable',
        context: 'System status could not be determined',
        color: AppColors.warning,
      );
    }

    final rawStatus = (data['raw_status'] ?? '').toString();

    if (rawStatus == 'started') {
      return const _OverviewStatus(
        value: 'Alert Active',
        context: 'Unsafe event is currently being detected',
        color: AppColors.danger,
      );
    }

    if (rawStatus == 'ended') {
      return const _OverviewStatus(
        value: 'Monitoring',
        context: 'Latest alert recently ended',
        color: AppColors.success,
      );
    }

    return const _OverviewStatus(
      value: 'Monitoring',
      context: 'System is actively watching for unsafe events',
      color: AppColors.primary,
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    _statusStream ??= FirebaseFirestore.instance
        .collection('status')
        .doc('current')
        .snapshots();

    _historyStream ??= FirebaseFirestore.instance
        .collection('events')
        .orderBy('client_time', descending: true)
        .limit(30)
        .snapshots();

    _notificationSettingsFuture ??= FirebaseMessaging.instance
        .getNotificationSettings();

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _statusStream,
          builder: (context, statusSnap) {
            final statusData = statusSnap.data?.data();

            final updatedAt = statusData?['updated_at']?.toString();
            final location = (statusData?['location_id'] ?? 'Unknown location')
                .toString();
            final confirmedDual = statusData?['confirmed_dual'] == true;
            final handoff = statusData?['handoff'] == true;

            final onlineCameraCount = _parseInt(
              statusData?['online_camera_count'],
            );
            final totalCameraCount = _parseInt(
              statusData?['total_camera_count'],
            );

            final firebaseStatus = _firebaseConnectionStatus(statusSnap);
            final overviewStatus = _overviewStatus(statusData);
            final lastSync = timeAgoFromIso(updatedAt);

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _historyStream,
              builder: (context, historySnap) {
                final docs = historySnap.data?.docs ?? [];

                final activeAlerts = docs
                    .where(
                      (doc) =>
                          (doc.data()['status'] ?? '').toString() == 'started',
                    )
                    .length;

                final resolvedAlerts = docs
                    .where(
                      (doc) =>
                          (doc.data()['status'] ?? '').toString() == 'ended',
                    )
                    .length;

                final eventsToday = docs.where((doc) {
                  final raw = doc.data()['logged_at']?.toString();
                  if (raw == null || raw.isEmpty) return false;
                  try {
                    final dt = DateTime.parse(raw).toLocal();
                    final now = DateTime.now();
                    return dt.year == now.year &&
                        dt.month == now.month &&
                        dt.day == now.day;
                  } catch (_) {
                    return false;
                  }
                }).length;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                  children: [
                    Text(
                      'System',
                      style: text.headlineSmall?.copyWith(fontSize: 26),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'System overview, operational health, and device status',
                      style: text.bodyMedium,
                    ),
                    const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.stroke),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _SummaryMetric(
                              title: '$activeAlerts',
                              label: 'Active Alerts',
                              accent: AppColors.danger,
                              icon: Icons.warning_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _SummaryMetric(
                              title: '$eventsToday',
                              label: 'Events Today',
                              accent: AppColors.primary,
                              icon: Icons.insights_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _SummaryMetric(
                              title: _cameraRatio(
                                onlineCameraCount,
                                totalCameraCount,
                              ),
                              label: 'Cameras',
                              accent: AppColors.success,
                              icon: Icons.videocam_rounded,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text('System Overview', style: text.titleLarge),
                    const SizedBox(height: 12),

                    _InfoCard(
                      title: 'System Status',
                      value: overviewStatus.value,
                      subtitle: overviewStatus.context,
                      icon: Icons.shield_rounded,
                      accent: overviewStatus.color,
                    ),
                    const SizedBox(height: 12),

                    _InfoCard(
                      title: 'Latest Location',
                      value: location,
                      subtitle: 'Most recent location reported by the system',
                      icon: Icons.place_rounded,
                      accent: AppColors.warning,
                    ),
                    const SizedBox(height: 12),

                    _InfoCard(
                      title: 'Last Sync',
                      value: lastSync == 'Unknown'
                          ? 'No recent update'
                          : lastSync,
                      subtitle: 'Most recent status update from Firestore',
                      icon: Icons.schedule_rounded,
                      accent: AppColors.primary,
                    ),

                    const SizedBox(height: 24),

                    Text('Verification Status', style: text.titleLarge),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _MiniStatusCard(
                            title: 'Dual Camera',
                            value: confirmedDual
                                ? 'Confirmed'
                                : 'Not Confirmed',
                            icon: confirmedDual
                                ? Icons.verified_rounded
                                : Icons.videocam_outlined,
                            accent: confirmedDual
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MiniStatusCard(
                            title: 'Handoff',
                            value: handoff ? 'Used' : 'Not Used',
                            icon: handoff
                                ? Icons.swap_horiz_rounded
                                : Icons.horizontal_rule_rounded,
                            accent: handoff
                                ? AppColors.primary
                                : AppColors.warning,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    Text('Health Status', style: text.titleLarge),
                    const SizedBox(height: 12),

                    _StatusTile(
                      icon: firebaseStatus.icon,
                      title: 'Firebase Connection',
                      value: firebaseStatus.label,
                      subtitle: firebaseStatus.subtitle,
                      accent: firebaseStatus.color,
                    ),
                    const SizedBox(height: 12),

                    FutureBuilder<NotificationSettings>(
                      future: _notificationSettingsFuture,
                      builder: (context, notifSnap) {
                        if (notifSnap.hasError) {
                          return const _StatusTile(
                            icon: Icons.notifications_off_rounded,
                            title: 'Notification Permission',
                            value: 'Error',
                            subtitle:
                                'Could not read the device notification permission',
                            accent: AppColors.danger,
                          );
                        }

                        if (!notifSnap.hasData) {
                          return const _StatusTile(
                            icon: Icons.notifications_rounded,
                            title: 'Notification Permission',
                            value: 'Checking',
                            subtitle: 'Reading current device permission...',
                            accent: AppColors.warning,
                          );
                        }

                        final notifStatus = _notificationStatus(
                          notifSnap.data!,
                        );

                        return _StatusTile(
                          icon: notifStatus.icon,
                          title: 'Notification Permission',
                          value: notifStatus.label,
                          subtitle: notifStatus.subtitle,
                          accent: notifStatus.color,
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    Text('Operational Summary', style: text.titleLarge),
                    const SizedBox(height: 12),

                    _InfoCard(
                      title: 'Resolved Alerts',
                      value: '$resolvedAlerts in recent activity',
                      subtitle:
                          'Resolved events within the recent activity window',
                      icon: Icons.check_circle_rounded,
                      accent: AppColors.success,
                    ),
                    const SizedBox(height: 12),

                    _InfoCard(
                      title: 'Recent Event Feed',
                      value: docs.isEmpty
                          ? 'No recent events available'
                          : '${docs.length} recent records loaded',
                      subtitle:
                          'Latest event records currently loaded in the app',
                      icon: Icons.history_rounded,
                      accent: AppColors.primary,
                    ),

                    if (statusSnap.hasError || historySnap.hasError) ...[
                      const SizedBox(height: 16),
                      const _NotesPanel(
                        text:
                            'Some Firestore data could not be loaded. Check network connectivity, Firebase setup, and emulator/device sync.',
                      ),
                    ],
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _StatusView {
  final String label;
  final String subtitle;
  final Color color;
  final IconData icon;

  const _StatusView({
    required this.label,
    required this.subtitle,
    required this.color,
    required this.icon,
  });
}

class _OverviewStatus {
  final String value;
  final String context;
  final Color color;

  const _OverviewStatus({
    required this.value,
    required this.context,
    required this.color,
  });
}

class _SummaryMetric extends StatelessWidget {
  final String title;
  final String label;
  final Color accent;
  final IconData icon;

  const _SummaryMetric({
    required this.title,
    required this.label,
    required this.accent,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: accent, size: 18),
        const SizedBox(height: 12),
        Text(title, style: text.headlineSmall?.copyWith(fontSize: 24)),
        const SizedBox(height: 4),
        Text(label, style: text.bodyMedium),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accent;

  const _InfoCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accent,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleMedium),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: text.titleSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
        ],
      ),
    );
  }
}

class _MiniStatusCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color accent;

  const _MiniStatusCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(height: 14),
          Text(title, style: text.titleMedium),
          const SizedBox(height: 6),
          Text(value, style: text.bodyMedium),
        ],
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color accent;

  const _StatusTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accent,
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
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent),
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
          Text(
            value,
            style: text.labelLarge?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesPanel extends StatelessWidget {
  final String text;

  const _NotesPanel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
          height: 1.5,
        ),
      ),
    );
  }
}
