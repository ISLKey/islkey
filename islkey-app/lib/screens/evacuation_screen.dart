import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/fire_models.dart';
import '../providers/fire_provider.dart';
import '../theme.dart';

/// Active-alarm evacuation roll call. Marshals mark each person Safe / Missing /
/// Injury and confirm All Clear (the server gates All Clear until the fire panel
/// has reset). Polls so multiple marshals stay in sync.
class EvacuationScreen extends ConsumerStatefulWidget {
  final FireIncident incident;
  const EvacuationScreen({super.key, required this.incident});

  @override
  ConsumerState<EvacuationScreen> createState() => _EvacuationScreenState();
}

class _EvacuationScreenState extends ConsumerState<EvacuationScreen> {
  List<RollCallEntry> _rows = [];
  int _expected = 0;
  int _accounted = 0;
  bool _panelClear = true;
  bool _loading = true;
  String? _error;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 8), (_) => _refresh(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final d = await ref.read(fireProvider.notifier).rollCall(widget.incident.id);
      final session = d['session'] as Map<String, dynamic>?;
      final list = ((d['roll_call'] as List?) ?? [])
          .map((e) => RollCallEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _rows = list;
        _expected = session == null ? 0 : int.tryParse('${session['expected_count']}') ?? 0;
        _accounted = session == null ? 0 : int.tryParse('${session['accounted_count']}') ?? 0;
        _panelClear = d['panel_clear'] != false;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _mark(RollCallEntry r, String status) async {
    // Optimistic update so the sweep feels instant.
    setState(() {
      _rows = _rows
          .map((e) => e.personId == r.personId
              ? RollCallEntry(
                  personId: e.personId,
                  name: e.name,
                  department: e.department,
                  status: status)
              : e)
          .toList();
    });
    try {
      await ref.read(fireProvider.notifier).mark(widget.incident.id, r.personId, status);
      await _refresh(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save — will retry: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _allClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Confirm All Clear'),
        content: const Text(
            'Confirm the evacuation is complete and everyone is accounted for? This closes the incident.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('All Clear')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(fireProvider.notifier).allClear(widget.incident.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: ISLTheme.error),
        );
      }
    }
  }

  Color _statusColour(String s) {
    switch (s) {
      case 'safe':
        return ISLTheme.success;
      case 'missing':
        return ISLTheme.warning;
      case 'injury':
        return ISLTheme.error;
      default:
        return ISLTheme.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final drill = widget.incident.isDrill;
    final headerColour = drill ? ISLTheme.warning : ISLTheme.fireColour;
    final allAccounted = _expected > 0 && _accounted >= _expected;

    return Scaffold(
      backgroundColor: ISLTheme.background,
      appBar: AppBar(
        backgroundColor: headerColour,
        foregroundColor: Colors.white,
        title: Text(drill ? 'FIRE DRILL — Roll Call' : 'FIRE ALARM — Roll Call'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      color: headerColour.withValues(alpha: 0.10),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          _stat('ELAPSED', '${widget.incident.elapsedMinutes} min'),
                          const SizedBox(width: 24),
                          _stat('ACCOUNTED', '$_accounted / $_expected'),
                          const Spacer(),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: allAccounted ? ISLTheme.success : ISLTheme.textMuted,
                            ),
                            onPressed: _panelClear ? _allClear : null,
                            child: const Text('All Clear'),
                          ),
                        ],
                      ),
                    ),
                    if (!_panelClear)
                      Container(
                        width: double.infinity,
                        color: ISLTheme.warning.withValues(alpha: 0.15),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: const Text(
                          '⚠ Fire panel still active — reset the panel before confirming All Clear.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    Expanded(
                      child: _rows.isEmpty
                          ? const Center(child: Text('No one was clocked in at this site.'))
                          : RefreshIndicator(
                              onRefresh: _refresh,
                              child: ListView.separated(
                                itemCount: _rows.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (_, i) => _rollRow(_rows[i]),
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _stat(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: ISLTheme.textMuted)),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ],
      );

  Widget _rollRow(RollCallEntry r) {
    return Container(
      color: ISLTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (r.department != null)
                  Text(r.department!, style: const TextStyle(fontSize: 12, color: ISLTheme.textMuted)),
                Text(r.status.toUpperCase(),
                    style: TextStyle(fontSize: 11, color: _statusColour(r.status), fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          _markBtn(r, 'safe', 'Safe', ISLTheme.success),
          const SizedBox(width: 6),
          _markBtn(r, 'missing', 'Missing', ISLTheme.warning),
          const SizedBox(width: 6),
          _markBtn(r, 'injury', 'Injury', ISLTheme.error),
        ],
      ),
    );
  }

  Widget _markBtn(RollCallEntry r, String status, String label, Color colour) {
    final selected = r.status == status;
    return SizedBox(
      width: 64,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: selected ? colour : colour.withValues(alpha: 0.12),
          foregroundColor: selected ? Colors.white : colour,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          minimumSize: const Size(0, 36),
        ),
        onPressed: () => _mark(r, status),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}
