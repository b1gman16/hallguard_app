import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class HomePage extends StatefulWidget {
  final VoidCallback onOpenSystem;

  const HomePage({super.key, required this.onOpenSystem});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Timer? _ticker;

  Stream<DocumentSnapshot<Map<String, dynamic>>>? _statusStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _historyStream;

  static const int resolvedSeconds = 5;

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
        .limit(10)
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

  DateTime? _parseIsoToLocal(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    try {
      return DateTime.parse(iso).toLocal();
    } catch (_) {
      return null;
    }
  }

  bool _isRecentlyResolved(String rawStatus, String? updatedAtIso) {
    if (rawStatus != 'ended') return false;

    final updatedAt = _parseIsoToLocal(updatedAtIso);
    if (updatedAt == null) return false;

    final diff = DateTime.now().difference(updatedAt);

    if (diff.isNegative) return true;
    return diff.inSeconds < resolvedSeconds;
  }

  _StatusUi _computeStatusUi(String rawStatus, String? updatedAtIso) {
    if (rawStatus == 'started') {
      return const _StatusUi(
        headline: 'UNSAFE EVENT',
        label: 'Live alert',
        accent: AppColors.danger,
        accentSoft: AppColors.dangerSoft,
        icon: Icons.warning_rounded,
      );
    }

    if (_isRecentlyResolved(rawStatus, updatedAtIso)) {
      return const _StatusUi(
        headline: 'RESOLVED',
        label: 'Alert cleared',
        accent: AppColors.success,
        accentSoft: AppColors.successSoft,
        icon: Icons.check_circle_rounded,
      );
    }

    return const _StatusUi(
      headline: 'MONITORING',
      label: 'Live monitoring',
      accent: AppColors.warning,
      accentSoft: AppColors.warningSoft,
      icon: Icons.remove_red_eye_rounded,
    );
  }

  String _statusDescription(String rawStatus, String? updatedAtIso) {
    if (rawStatus == 'started') {
      return 'Unsafe hallway activity needs immediate attention.';
    }

    if (_isRecentlyResolved(rawStatus, updatedAtIso)) {
      return 'The latest alert has ended and the system is back to watch mode.';
    }

    return 'System is actively monitoring hallway activity for unsafe events.';
  }

  int _cameraCount(dynamic camerasSeen) {
    if (camerasSeen is List) return camerasSeen.length;
    if (camerasSeen == null) return 0;

    final text = camerasSeen.toString().trim();
    if (text.isEmpty) return 0;

    return text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .length;
  }

  String _cameraLabel(dynamic camerasSeen) {
    final count = _cameraCount(camerasSeen);
    if (count == 0) return 'No camera data';
    if (count == 1) return '1 Camera In Event';
    return '$count Cameras In Event';
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString());
  }

  String _cameraOnlineTitle(int? onlineCount, int? totalCount) {
    if (onlineCount == null || totalCount == null) return '--';
    return '$onlineCount/$totalCount';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallPhone = screenWidth < 380;

    _statusStream ??= FirebaseFirestore.instance
        .collection('status')
        .doc('current')
        .snapshots();

    _historyStream ??= FirebaseFirestore.instance
        .collection('events')
        .orderBy('client_time', descending: true)
        .limit(10)
        .snapshots();

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _statusStream,
          builder: (context, statusSnap) {
            final statusData = statusSnap.data?.data();

            final rawStatus = (statusData?['raw_status'] ?? '').toString();
            final location = (statusData?['location_id'] ?? 'Unknown location')
                .toString();
            final updatedAtIso = statusData?['updated_at']?.toString();
            final camerasSeen = statusData?['cameras_seen'];
            final confirmedDual = statusData?['confirmed_dual'] == true;

            final onlineCameraCount = _parseInt(
              statusData?['online_camera_count'],
            );
            final totalCameraCount = _parseInt(
              statusData?['total_camera_count'],
            );

            final statusUi = _computeStatusUi(rawStatus, updatedAtIso);
            final updatedText = timeAgoFromIso(updatedAtIso);
            final description = _statusDescription(rawStatus, updatedAtIso);

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
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'HallGuard',
                                style: text.headlineSmall?.copyWith(
                                  fontSize: isSmallPhone ? 24 : 26,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Hallway Safety Monitoring',
                                style: text.bodyMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: widget.onOpenSystem,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.stroke),
                            ),
                            child: const Icon(
                              Icons.settings_input_component_rounded,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: EdgeInsets.all(isSmallPhone ? 18 : 20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF1A2330), Color(0xFF101720)],
                        ),
                        border: Border.all(color: AppColors.stroke),
                      ),
                      child: statusSnap.hasError
                          ? const _HeroErrorState()
                          : statusSnap.connectionState ==
                                ConnectionState.waiting
                          ? const _HeroLoadingState()
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusUi.accentSoft,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        statusUi.icon,
                                        size: 16,
                                        color: statusUi.accent,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        statusUi.label.toUpperCase(),
                                        style: TextStyle(
                                          color: statusUi.accent,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  statusUi.headline,
                                  style: text.headlineMedium?.copyWith(
                                    fontSize: isSmallPhone ? 28 : 32,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  description,
                                  style: text.bodyMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    _MetaChip(
                                      icon: Icons.place_rounded,
                                      label: location,
                                    ),
                                    _MetaChip(
                                      icon: Icons.schedule_rounded,
                                      label: updatedText == 'Unknown'
                                          ? 'Updated --'
                                          : 'Updated $updatedText',
                                    ),
                                    _MetaChip(
                                      icon: Icons.videocam_rounded,
                                      label: _cameraLabel(camerasSeen),
                                    ),
                                    if (confirmedDual)
                                      const _MetaChip(
                                        icon: Icons.verified_rounded,
                                        label: 'Dual confirmed',
                                      ),
                                  ],
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _StatTile(
                            title: '$activeAlerts',
                            label: 'Active Alerts',
                            icon: Icons.warning_amber_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatTile(
                            title: '$eventsToday',
                            label: 'Events Today',
                            icon: Icons.insights_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _StatTile(
                      title: _cameraOnlineTitle(
                        onlineCameraCount,
                        totalCameraCount,
                      ),
                      label: 'Cameras Online',
                      icon: Icons.videocam_rounded,
                      fullWidth: true,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Text('Recent Alerts', style: text.titleLarge),
                        ),
                        Text(
                          'Latest ${docs.length}',
                          style: text.labelMedium?.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (historySnap.hasError)
                      const _SimpleInfoCard(
                        text: 'Could not load recent events.',
                      )
                    else if (historySnap.connectionState ==
                        ConnectionState.waiting)
                      const _SimpleInfoCard(text: 'Loading recent events...')
                    else if (docs.isEmpty)
                      const _SimpleInfoCard(text: 'No recent events yet.')
                    else
                      ...docs.take(3).map((doc) {
                        final data = doc.data();
                        final eventId = data['event_id']?.toString() ?? doc.id;
                        final eventStatus = (data['status'] ?? 'unknown')
                            .toString();
                        final eventLocation =
                            (data['location_id'] ?? 'Unknown location')
                                .toString();
                        final when = timeAgoFromIso(
                          data['logged_at']?.toString(),
                        );

                        final isDanger = eventStatus == 'started';

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _AlertPreviewCard(
                            title: isDanger
                                ? 'Unsafe behavior detected'
                                : 'Alert cleared',
                            location: '$eventLocation • $when',
                            status: isDanger ? 'ACTIVE' : 'RESOLVED',
                            eventId: eventId,
                            isDanger: isDanger,
                          ),
                        );
                      }),
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

class _StatusUi {
  final String headline;
  final String label;
  final Color accent;
  final Color accentSoft;
  final IconData icon;

  const _StatusUi({
    required this.headline,
    required this.label,
    required this.accent,
    required this.accentSoft,
    required this.icon,
  });
}

class _HeroLoadingState extends StatelessWidget {
  const _HeroLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text(
          'Loading live status...',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _HeroErrorState extends StatelessWidget {
  const _HeroErrorState();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Status unavailable',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Could not load the live monitoring status.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
      ],
    );
  }
}

class _SimpleInfoCard extends StatelessWidget {
  final String text;

  const _SimpleInfoCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String title;
  final String label;
  final IconData icon;
  final bool fullWidth;

  const _StatTile({
    required this.title,
    required this.label,
    required this.icon,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.headlineSmall?.copyWith(fontSize: 24)),
                const SizedBox(height: 4),
                Text(label, style: text.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.stroke),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertPreviewCard extends StatelessWidget {
  final String title;
  final String location;
  final String status;
  final String eventId;
  final bool isDanger;

  const _AlertPreviewCard({
    required this.title,
    required this.location,
    required this.status,
    required this.eventId,
    required this.isDanger,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final accent = isDanger ? AppColors.danger : AppColors.success;
    final soft = isDanger ? AppColors.dangerSoft : AppColors.successSoft;

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
              color: soft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isDanger ? Icons.warning_rounded : Icons.check_circle_rounded,
              color: accent,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleMedium),
                const SizedBox(height: 6),
                Text(
                  location,
                  style: text.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  'Event ID: $eventId',
                  style: text.labelMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: soft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
