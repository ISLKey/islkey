import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/access_event.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/shared_widgets.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  List<AccessEvent> _events = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final authState = ref.read(authProvider);
      final profile = authState.profile;
      if (profile == null) return;

      final api = ApiService(apiBase: profile.apiBase, token: authState.token);
      final events = await api.fetchLog();
      setState(() {
        _events = events;
        _loading = false;
      });
    } on TokenExpiredException {
      ref.read(authProvider.notifier).onTokenExpired();
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } on NetworkException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Could not load history. Please try again.';
        _loading = false;
      });
    }
  }

  Map<String, List<AccessEvent>> _groupByDate(List<AccessEvent> events) {
    final grouped = <String, List<AccessEvent>>{};
    for (final event in events) {
      final key =
          DateFormat('EEEE d MMMM yyyy').format(event.timestamp.toLocal());
      grouped.putIfAbsent(key, () => []).add(event);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final brandColour = ref.watch(
      authProvider.select((s) {
        final b = s.profile?.branding;
        return b != null ? ISLTheme.fromHex(b.brandColour) : ISLTheme.primary;
      }),
    );

    return Scaffold(
      backgroundColor: ISLTheme.background,
      appBar: AppBar(
        backgroundColor: brandColour,
        title: const Text('Access History'),
        leading: const BackButton(color: Colors.white),
      ),
      body: _buildBody(brandColour),
    );
  }

  Widget _buildBody(Color brandColour) {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(brandColour),
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ErrorBanner(_error!),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: brandColour),
              onPressed: _load,
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }

    if (_events.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 56, color: ISLTheme.textMuted),
            SizedBox(height: 16),
            Text(
              'No access events yet.',
              style: TextStyle(color: ISLTheme.textMuted, fontSize: 16),
            ),
          ],
        ),
      );
    }

    final grouped = _groupByDate(_events);
    final keys = grouped.keys.toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: keys.length,
        itemBuilder: (context, i) {
          final dateKey = keys[i];
          final dayEvents = grouped[dateKey]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeading(dateKey),
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: ISLTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: const Border.fromBorderSide(
                    BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                ),
                child: Column(
                  children:
                      dayEvents.map((e) => AccessEventTile(event: e)).toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
