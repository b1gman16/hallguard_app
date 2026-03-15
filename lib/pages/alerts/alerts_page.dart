import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  Timer? _ticker;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _historyStream;

  _AlertFilter _filter = _AlertFilter.all;

  @override
  void initState() {
    super.initState();

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

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyFilter(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    switch (_filter) {
      case _AlertFilter.all:
        return docs;
      case _AlertFilter.active:
        return docs
            .where(
              (doc) => (doc.data()['status'] ?? '').toString() == 'started',
            )
            .toList();
      case _AlertFilter.resolved:
        return docs
            .where((doc) => (doc.data()['status'] ?? '').toString() == 'ended')
            .toList();
    }
  }

  int _cameraCount(dynamic camerasSeen) {
    if (camerasSeen is List) return camerasSeen.length;
    if (camerasSeen == null) return 0;

    final raw = camerasSeen.toString().trim();
    if (raw.isEmpty) return 0;

    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .length;
  }

  String _cameraSummary(dynamic camerasSeen) {
    final count = _cameraCount(camerasSeen);
    if (count == 0) return 'No camera data';
    if (count == 1) return '1 camera';
    return '$count cameras';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    _historyStream ??= FirebaseFirestore.instance
        .collection('events')
        .orderBy('client_time', descending: true)
        .limit(30)
        .snapshots();

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _historyStream,
          builder: (context, snap) {
            final docs = snap.data?.docs ?? [];
            final filteredDocs = _applyFilter(docs);

            final activeCount = docs
                .where(
                  (doc) => (doc.data()['status'] ?? '').toString() == 'started',
                )
                .length;

            final resolvedCount = docs
                .where(
                  (doc) => (doc.data()['status'] ?? '').toString() == 'ended',
                )
                .length;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
              children: [
                Text(
                  'Alerts',
                  style: text.headlineSmall?.copyWith(fontSize: 26),
                ),
                const SizedBox(height: 4),
                Text(
                  'Review active and resolved hallway incidents',
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
                          title: '$activeCount',
                          label: 'Active',
                          accent: AppColors.danger,
                          icon: Icons.warning_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryMetric(
                          title: '$resolvedCount',
                          label: 'Resolved',
                          accent: AppColors.success,
                          icon: Icons.check_circle_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryMetric(
                          title: '${docs.length}',
                          label: 'Total',
                          accent: AppColors.primary,
                          icon: Icons.history_rounded,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All',
                        selected: _filter == _AlertFilter.all,
                        onTap: () => setState(() => _filter = _AlertFilter.all),
                      ),
                      const SizedBox(width: 10),
                      _FilterChip(
                        label: 'Active',
                        selected: _filter == _AlertFilter.active,
                        onTap: () =>
                            setState(() => _filter = _AlertFilter.active),
                      ),
                      const SizedBox(width: 10),
                      _FilterChip(
                        label: 'Resolved',
                        selected: _filter == _AlertFilter.resolved,
                        onTap: () =>
                            setState(() => _filter = _AlertFilter.resolved),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                if (snap.hasError)
                  const _InfoPanel(
                    text: 'Could not load alerts from Firestore.',
                  )
                else if (snap.connectionState == ConnectionState.waiting)
                  const _InfoPanel(text: 'Loading alerts...')
                else if (filteredDocs.isEmpty)
                  _InfoPanel(
                    text: _filter == _AlertFilter.all
                        ? 'No alerts yet.'
                        : _filter == _AlertFilter.active
                        ? 'No active alerts right now.'
                        : 'No resolved alerts yet.',
                  )
                else
                  ...filteredDocs.map((doc) {
                    final data = doc.data();

                    final eventId = data['event_id']?.toString() ?? doc.id;
                    final status = (data['status'] ?? 'unknown').toString();
                    final location = (data['location_id'] ?? 'Unknown location')
                        .toString();
                    final loggedAt = data['logged_at']?.toString();
                    final when = timeAgoFromIso(loggedAt);

                    final camerasSeen = data['cameras_seen'];
                    final confirmedDual = data['confirmed_dual'] == true;
                    final handoff = data['handoff'] == true;

                    final isActive = status == 'started';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _AlertCard(
                        title: isActive
                            ? 'Unsafe behavior detected'
                            : 'Alert cleared',
                        location: location,
                        time: when,
                        eventId: eventId,
                        statusLabel: isActive ? 'ACTIVE' : 'RESOLVED',
                        isActive: isActive,
                        cameraLabel: _cameraSummary(camerasSeen),
                        dualConfirmed: confirmedDual,
                        handoff: handoff,
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}

enum _AlertFilter { all, active, resolved }

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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.primary : AppColors.surface;
    final fg = selected ? Colors.white : AppColors.textPrimary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.stroke,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final String title;
  final String location;
  final String time;
  final String eventId;
  final String statusLabel;
  final bool isActive;
  final String cameraLabel;
  final bool dualConfirmed;
  final bool handoff;

  const _AlertCard({
    required this.title,
    required this.location,
    required this.time,
    required this.eventId,
    required this.statusLabel,
    required this.isActive,
    required this.cameraLabel,
    required this.dualConfirmed,
    required this.handoff,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final accent = isActive ? AppColors.danger : AppColors.success;
    final soft = isActive ? AppColors.dangerSoft : AppColors.successSoft;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: soft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isActive ? Icons.warning_rounded : Icons.check_circle_rounded,
                  color: accent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      '$location • $time',
                      style: text.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: soft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text('Event ID: $eventId', style: text.labelMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetaBadge(icon: Icons.videocam_rounded, label: cameraLabel),
              _MetaBadge(
                icon: dualConfirmed
                    ? Icons.verified_rounded
                    : Icons.videocam_outlined,
                label: dualConfirmed ? 'Dual confirmed' : 'Single camera',
              ),
              _MetaBadge(
                icon: handoff
                    ? Icons.swap_horiz_rounded
                    : Icons.horizontal_rule_rounded,
                label: handoff ? 'Handoff used' : 'No handoff',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.bg,
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

class _InfoPanel extends StatelessWidget {
  final String text;

  const _InfoPanel({required this.text});

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
