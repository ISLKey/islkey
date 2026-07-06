import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/fire_models.dart';
import '../providers/fire_provider.dart';
import '../theme.dart';
import 'evacuation_screen.dart';

/// The Fire tab — visible only to fire marshals/wardens. Shows their assignment
/// in the normal state, and a prominent alert + evacuation entry when a fire
/// event is active on one of their sites. Polls so an alarm surfaces promptly
/// (push notification delivery is a follow-up, pending the provider decision).
class FireScreen extends ConsumerStatefulWidget {
  const FireScreen({super.key});

  @override
  ConsumerState<FireScreen> createState() => _FireScreenState();
}

class _FireScreenState extends ConsumerState<FireScreen> {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(fireProvider.notifier).load();
    });
    _poll = Timer.periodic(
        const Duration(seconds: 15), (_) => ref.read(fireProvider.notifier).load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _openEvacuation(FireIncident inc) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EvacuationScreen(incident: inc)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fire = ref.watch(fireProvider);
    final active = fire.activeIncident;

    return Scaffold(
      backgroundColor: ISLTheme.background,
      appBar: AppBar(
        backgroundColor: ISLTheme.fireColour,
        foregroundColor: Colors.white,
        title: const Text('Fire'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(fireProvider.notifier).load(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (active != null) _activeCard(active) else _normalStatus(),
            const SizedBox(height: 8),
            const Text('Your Fire Roles',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 8),
            if (fire.sites.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('You are not assigned as a fire marshal at any site.'),
              )
            else
              ...fire.sites.map(_siteCard),
          ],
        ),
      ),
    );
  }

  Widget _normalStatus() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ISLTheme.success.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: const Border(left: BorderSide(color: ISLTheme.success, width: 4)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle, color: ISLTheme.success),
            SizedBox(width: 12),
            Expanded(
              child: Text('All clear. No active fire events on your sites.',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  Widget _activeCard(FireIncident inc) {
    final drill = inc.isDrill;
    final colour = drill ? ISLTheme.warning : ISLTheme.fireColour;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: colour, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(drill ? Icons.campaign : Icons.local_fire_department, color: colour),
              const SizedBox(width: 10),
              Text(drill ? 'FIRE DRILL' : 'FIRE ALARM',
                  style: TextStyle(color: colour, fontWeight: FontWeight.w800, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 6),
          Text('Started ${inc.elapsedMinutes} min ago. Conduct the roll call now.'),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: colour),
              icon: const Icon(Icons.people),
              label: const Text('Open Evacuation Roll Call'),
              onPressed: () => _openEvacuation(inc),
            ),
          ),
        ],
      ),
    );
  }

  Widget _siteCard(FireMarshalSite site) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(site.siteName,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: ISLTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(site.isMarshal ? 'Marshal' : 'Warden',
                      style: const TextStyle(fontSize: 12, color: ISLTheme.primary)),
                ),
              ],
            ),
            if (site.zone != null && site.zone!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Zone: ${site.zone}',
                    style: const TextStyle(fontSize: 13, color: ISLTheme.textMuted)),
              ),
            const Divider(height: 20),
            _SiteSummary(siteId: site.siteId),
          ],
        ),
      ),
    );
  }
}

/// Lazily loads the per-site normal-state summary (drill due + co-marshals).
class _SiteSummary extends ConsumerStatefulWidget {
  final int siteId;
  const _SiteSummary({required this.siteId});

  @override
  ConsumerState<_SiteSummary> createState() => _SiteSummaryState();
}

class _SiteSummaryState extends ConsumerState<_SiteSummary> {
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await ref.read(fireProvider.notifier).summary(widget.siteId);
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Text(_error!, style: const TextStyle(fontSize: 12, color: ISLTheme.textMuted));
    }
    if (_data == null) {
      return const SizedBox(
          height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2));
    }
    final sched = _data!['schedule'] as Map<String, dynamic>?;
    final marshals = (_data!['marshals'] as List?) ?? [];
    final nextDue = sched?['next_drill_due'];
    final others = marshals
        .map((m) => (m as Map<String, dynamic>)['full_name'] as String?)
        .where((n) => n != null)
        .cast<String>()
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.event, size: 16, color: ISLTheme.textMuted),
            const SizedBox(width: 6),
            Text('Next drill due: ${nextDue ?? 'not scheduled'}',
                style: const TextStyle(fontSize: 13)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.groups, size: 16, color: ISLTheme.textMuted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                others.isEmpty ? 'No other marshals' : 'Marshals: ${others.join(', ')}',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
