import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  Timer? _ticker;

  Stream<DocumentSnapshot>? _statusStream;
  Stream<QuerySnapshot>? _historyStream;

  // When an "ended" arrives, show RESOLVED briefly, then return to MONITORING.
  DateTime? _resolvedUntilLocal;
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
        .limit(30)
        .snapshots();

    // Tick so "Last updated X ago" updates even without new Firestore updates
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  bool get _isInResolvedWindow {
    if (_resolvedUntilLocal == null) return false;
    return DateTime.now().isBefore(_resolvedUntilLocal!);
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

  _StatusUI _computeStatusUi({required String rawStatus}) {
    if (rawStatus == 'started') {
      _resolvedUntilLocal = null;
      return const _StatusUI(
        headline: 'UNSAFE',
        subLabel: 'Alert active',
        icon: Icons.warning_rounded,
        tone: _Tone.danger,
      );
    }

    if (rawStatus == 'ended') {
      _resolvedUntilLocal ??= DateTime.now().add(
        const Duration(seconds: resolvedSeconds),
      );

      if (_isInResolvedWindow) {
        return const _StatusUI(
          headline: 'RESOLVED',
          subLabel: 'Alert cleared',
          icon: Icons.check_circle_rounded,
          tone: _Tone.success,
        );
      }
    }

    return const _StatusUI(
      headline: 'MONITORING',
      subLabel: 'System running',
      icon: Icons.visibility_rounded,
      tone: _Tone.neutral,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Robust for hot reload
    _statusStream ??= FirebaseFirestore.instance
        .collection('status')
        .doc('current')
        .snapshots();

    _historyStream ??= FirebaseFirestore.instance
        .collection('events')
        .orderBy('client_time', descending: true)
        .limit(30)
        .snapshots();

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('HallGuard')),
      body: SafeArea(
        child: Column(
          children: [
            // =========================
            // STATUS CARD
            // =========================
            StreamBuilder<DocumentSnapshot>(
              stream: _statusStream!,
              builder: (context, snap) {
                if (snap.hasError) {
                  return _pad(
                    _InfoCard(
                      title: 'Status unavailable',
                      subtitle: '${snap.error}',
                      icon: Icons.error_outline_rounded,
                      tone: _Tone.neutral,
                    ),
                  );
                }

                if (snap.connectionState == ConnectionState.waiting) {
                  return _pad(const _LoadingStatusCard());
                }

                if (!snap.hasData || !snap.data!.exists) {
                  return _pad(
                    const _InfoCard(
                      title: 'No live status yet',
                      subtitle: 'Run the edge app to create status/current.',
                      icon: Icons.info_outline_rounded,
                      tone: _Tone.neutral,
                    ),
                  );
                }

                final data = snap.data!.data() as Map<String, dynamic>;

                final rawStatus = (data['raw_status'] ?? '').toString();
                final eventId = data['event_id']?.toString() ?? '';
                final location = (data['location_id'] ?? 'unknown').toString();

                final camerasSeen = (data['cameras_seen'] is List)
                    ? (data['cameras_seen'] as List).join(', ')
                    : (data['cameras_seen']?.toString() ?? '');

                final confirmedDual = data['confirmed_dual'] == true;
                final handoff = data['handoff'] == true;

                final updatedAtIso = data['updated_at']?.toString();
                final lastUpdated = timeAgoFromIso(updatedAtIso);

                final statusUi = _computeStatusUi(rawStatus: rawStatus);
                final toneColors = _toneColors(scheme, statusUi.tone);

                return _pad(
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: scheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Icon badge
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: toneColors.bg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: toneColors.border),
                            ),
                            child: Icon(statusUi.icon, color: toneColors.fg),
                          ),
                          const SizedBox(width: 12),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  statusUi.subLabel.toUpperCase(),
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                        letterSpacing: 0.8,
                                      ),
                                ),
                                const SizedBox(height: 6),

                                // ✅ Wrap fixes overflow / overlap on small screens
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      statusUi.headline,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                            height: 1.1,
                                          ),
                                    ),
                                    _Pill(
                                      text: lastUpdated == 'Unknown'
                                          ? 'Updated —'
                                          : 'Updated $lastUpdated',
                                      icon: Icons.schedule_rounded,
                                      bg: scheme.surfaceContainerHighest,
                                      fg: scheme.onSurfaceVariant,
                                      border: scheme.outlineVariant,
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),

                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _Pill(
                                      text: _shorten(location, 28),
                                      icon: Icons.place_rounded,
                                      bg: scheme.surfaceContainerHighest,
                                      fg: scheme.onSurface,
                                      border: scheme.outlineVariant,
                                    ),
                                    _Pill(
                                      text: confirmedDual
                                          ? 'Dual confirmed'
                                          : 'Single cam',
                                      icon: confirmedDual
                                          ? Icons.verified_rounded
                                          : Icons.videocam_rounded,
                                      bg: scheme.surfaceContainerHighest,
                                      fg: scheme.onSurface,
                                      border: scheme.outlineVariant,
                                    ),
                                    _Pill(
                                      text: handoff ? 'Handoff' : 'No handoff',
                                      icon: handoff
                                          ? Icons.swap_horiz_rounded
                                          : Icons.horizontal_rule_rounded,
                                      bg: scheme.surfaceContainerHighest,
                                      fg: scheme.onSurface,
                                      border: scheme.outlineVariant,
                                    ),
                                    if (camerasSeen.isNotEmpty)
                                      _Pill(
                                        text: _shorten(
                                          'Cams: $camerasSeen',
                                          30,
                                        ),
                                        icon: Icons.camera_alt_rounded,
                                        bg: scheme.surfaceContainerHighest,
                                        fg: scheme.onSurface,
                                        border: scheme.outlineVariant,
                                      ),
                                  ],
                                ),

                                if (eventId.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    'Event: $eventId • $rawStatus',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(width: 8),
                          _StatusChip(
                            label: statusUi.headline,
                            tone: statusUi.tone,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            // =========================
            // HISTORY HEADER
            // =========================
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
              child: Row(
                children: [
                  Icon(Icons.history_rounded, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(
                    'Recent events',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Last 30',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            // =========================
            // HISTORY LIST
            // =========================
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _historyStream!,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(child: Text('Error: ${snap.error}'));
                  }
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snap.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(child: Text('No events yet.'));
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final d = docs[i].data() as Map<String, dynamic>;

                      final eventId = d['event_id']?.toString() ?? docs[i].id;
                      final status = (d['status'] ?? 'unknown').toString();
                      final location = (d['location_id'] ?? 'unknown')
                          .toString();

                      final camerasSeen = (d['cameras_seen'] is List)
                          ? (d['cameras_seen'] as List).join(', ')
                          : (d['cameras_seen']?.toString() ?? '');

                      final confirmedDual = d['confirmed_dual'] == true;
                      final handoff = d['handoff'] == true;

                      final loggedAtIso = d['logged_at']?.toString();
                      final when = timeAgoFromIso(loggedAtIso);

                      final isUnsafe = status == 'started';
                      final tone = isUnsafe ? _Tone.danger : _Tone.success;
                      final toneColors = _toneColors(scheme, tone);

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: BorderSide(color: scheme.outlineVariant),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: toneColors.bg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: toneColors.border),
                                ),
                                child: Icon(
                                  isUnsafe
                                      ? Icons.warning_rounded
                                      : Icons.check_circle_rounded,
                                  color: toneColors.fg,
                                ),
                              ),
                              const SizedBox(width: 12),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Event $eventId',
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w900,
                                                ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          when,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelMedium
                                              ?.copyWith(
                                                color: scheme.onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),

                                    Text(
                                      location,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                    ),

                                    const SizedBox(height: 10),

                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _Pill(
                                          text: isUnsafe
                                              ? 'UNSAFE START'
                                              : 'ENDED',
                                          icon: isUnsafe
                                              ? Icons.warning_rounded
                                              : Icons.flag_rounded,
                                          bg: toneColors.bg,
                                          fg: toneColors.fg,
                                          border: toneColors.border,
                                        ),
                                        _Pill(
                                          text: confirmedDual
                                              ? 'Dual'
                                              : 'Single',
                                          icon: confirmedDual
                                              ? Icons.verified_rounded
                                              : Icons.videocam_rounded,
                                          bg: scheme.surfaceContainerHighest,
                                          fg: scheme.onSurface,
                                          border: scheme.outlineVariant,
                                        ),
                                        _Pill(
                                          text: handoff
                                              ? 'Handoff'
                                              : 'No handoff',
                                          icon: handoff
                                              ? Icons.swap_horiz_rounded
                                              : Icons.horizontal_rule_rounded,
                                          bg: scheme.surfaceContainerHighest,
                                          fg: scheme.onSurface,
                                          border: scheme.outlineVariant,
                                        ),
                                        if (camerasSeen.isNotEmpty)
                                          _Pill(
                                            text: _shorten(camerasSeen, 28),
                                            icon: Icons.camera_alt_rounded,
                                            bg: scheme.surfaceContainerHighest,
                                            fg: scheme.onSurface,
                                            border: scheme.outlineVariant,
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 10),
                              _MiniChip(
                                label: isUnsafe ? 'UNSAFE' : 'ENDED',
                                tone: tone,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pad(Widget child) =>
      Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: child);

  static String _shorten(String s, int max) {
    if (s.length <= max) return s;
    return '${s.substring(0, max - 1)}…';
  }

  _ToneColors _toneColors(ColorScheme scheme, _Tone tone) {
    switch (tone) {
      case _Tone.danger:
        return _ToneColors(
          fg: scheme.error,
          bg: scheme.errorContainer,
          border: scheme.error.withOpacity(0.35),
        );
      case _Tone.success:
        return _ToneColors(
          fg: scheme.tertiary,
          bg: scheme.tertiaryContainer,
          border: scheme.tertiary.withOpacity(0.35),
        );
      case _Tone.neutral:
        return _ToneColors(
          fg: scheme.primary,
          bg: scheme.primaryContainer,
          border: scheme.primary.withOpacity(0.25),
        );
    }
  }
}

// ---------- UI helpers ----------

enum _Tone { danger, success, neutral }

class _ToneColors {
  final Color fg;
  final Color bg;
  final Color border;
  _ToneColors({required this.fg, required this.bg, required this.border});
}

class _StatusUI {
  final String headline;
  final String subLabel;
  final IconData icon;
  final _Tone tone;

  const _StatusUI({
    required this.headline,
    required this.subLabel,
    required this.icon,
    required this.tone,
  });
}

class _StatusChip extends StatelessWidget {
  final String label;
  final _Tone tone;

  const _StatusChip({required this.label, required this.tone});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color bg, fg, border;

    switch (tone) {
      case _Tone.danger:
        bg = scheme.errorContainer;
        fg = scheme.error;
        border = scheme.error.withOpacity(0.35);
        break;
      case _Tone.success:
        bg = scheme.tertiaryContainer;
        fg = scheme.tertiary;
        border = scheme.tertiary.withOpacity(0.35);
        break;
      case _Tone.neutral:
        bg = scheme.primaryContainer;
        fg = scheme.primary;
        border = scheme.primary.withOpacity(0.25);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: fg,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final _Tone tone;

  const _MiniChip({required this.label, required this.tone});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color bg, fg, border;

    switch (tone) {
      case _Tone.danger:
        bg = scheme.errorContainer;
        fg = scheme.error;
        border = scheme.error.withOpacity(0.35);
        break;
      case _Tone.success:
        bg = scheme.tertiaryContainer;
        fg = scheme.tertiary;
        border = scheme.tertiary.withOpacity(0.35);
        break;
      case _Tone.neutral:
        bg = scheme.primaryContainer;
        fg = scheme.primary;
        border = scheme.primary.withOpacity(0.25);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: fg,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color bg;
  final Color fg;
  final Color border;

  const _Pill({
    required this.text,
    required this.icon,
    required this.bg,
    required this.fg,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final _Tone tone;

  const _InfoCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Color bg, fg, border;
    switch (tone) {
      case _Tone.danger:
        bg = scheme.errorContainer;
        fg = scheme.error;
        border = scheme.error.withOpacity(0.35);
        break;
      case _Tone.success:
        bg = scheme.tertiaryContainer;
        fg = scheme.tertiary;
        border = scheme.tertiary.withOpacity(0.35);
        break;
      case _Tone.neutral:
        bg = scheme.surfaceContainerHighest;
        fg = scheme.onSurfaceVariant;
        border = scheme.outlineVariant;
        break;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border),
              ),
              child: Icon(icon, color: fg),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingStatusCard extends StatelessWidget {
  const _LoadingStatusCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 46,
              height: 46,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            SizedBox(width: 12),
            Expanded(child: Text('Loading live status...')),
          ],
        ),
      ),
    );
  }
}
