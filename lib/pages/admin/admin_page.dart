import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  Timer? _ticker;

  Stream<DocumentSnapshot<Map<String, dynamic>>>? _statusStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _historyStream;

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

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _statusStream,
          builder: (context, statusSnap) {
            final statusData = statusSnap.data?.data();

            final rawStatus = (statusData?['raw_status'] ?? '').toString();
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

            final monitoringLabel = rawStatus == 'started'
                ? 'Unsafe event active'
                : rawStatus == 'ended'
                ? 'Alert recently ended'
                : 'Monitoring normally';

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
                      'Admin',
                      style: text.headlineSmall?.copyWith(fontSize: 26),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'System overview and operational health',
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

                    const SizedBox(height: 20),

                    Text('System Overview', style: text.titleLarge),
                    const SizedBox(height: 12),

                    _InfoCard(
                      title: 'Monitoring Status',
                      value: monitoringLabel,
                      icon: Icons.shield_rounded,
                      accent: rawStatus == 'started'
                          ? AppColors.danger
                          : AppColors.primary,
                    ),
                    const SizedBox(height: 12),
                    _InfoCard(
                      title: 'Latest Location',
                      value: location,
                      icon: Icons.place_rounded,
                      accent: AppColors.warning,
                    ),
                    const SizedBox(height: 12),
                    _InfoCard(
                      title: 'Last Sync',
                      value: timeAgoFromIso(updatedAt) == 'Unknown'
                          ? 'No recent update'
                          : timeAgoFromIso(updatedAt),
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

                    Text('Operational Summary', style: text.titleLarge),
                    const SizedBox(height: 12),

                    _InfoCard(
                      title: 'Resolved Alerts',
                      value: '$resolvedAlerts in recent activity',
                      icon: Icons.check_circle_rounded,
                      accent: AppColors.success,
                    ),
                    const SizedBox(height: 12),
                    _InfoCard(
                      title: 'Recent Event Feed',
                      value: docs.isEmpty
                          ? 'No recent events available'
                          : '${docs.length} recent records loaded',
                      icon: Icons.history_rounded,
                      accent: AppColors.primary,
                    ),

                    const SizedBox(height: 24),

                    Text('Admin Notes', style: text.titleLarge),
                    const SizedBox(height: 12),

                    const _NotesPanel(
                      text:
                          'This dashboard is intended for system monitoring, device-health awareness, and quick operational review. Advanced controls can be added later if needed.',
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
  final IconData icon;
  final Color accent;

  const _InfoCard({
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
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.14),
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
