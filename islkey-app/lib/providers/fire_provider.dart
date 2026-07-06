import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/fire_models.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

class FireState {
  final bool loading;
  final bool isMarshal;
  final List<FireMarshalSite> sites;
  final List<FireIncident> activeIncidents;
  final String? error;

  const FireState({
    this.loading = false,
    this.isMarshal = false,
    this.sites = const [],
    this.activeIncidents = const [],
    this.error,
  });

  FireIncident? get activeIncident =>
      activeIncidents.isNotEmpty ? activeIncidents.first : null;

  FireState copyWith({
    bool? loading,
    bool? isMarshal,
    List<FireMarshalSite>? sites,
    List<FireIncident>? activeIncidents,
    String? error,
  }) =>
      FireState(
        loading: loading ?? this.loading,
        isMarshal: isMarshal ?? this.isMarshal,
        sites: sites ?? this.sites,
        activeIncidents: activeIncidents ?? this.activeIncidents,
        error: error,
      );
}

class FireNotifier extends Notifier<FireState> {
  @override
  FireState build() => const FireState();

  ApiService get _api {
    final auth = ref.read(authProvider);
    return ApiService(apiBase: auth.profile?.apiBase ?? '', token: auth.token);
  }

  /// Refresh marshal status + active incidents. Never throws.
  Future<void> load() async {
    final auth = ref.read(authProvider);
    if (auth.profile == null || auth.token == null) {
      state = const FireState();
      return;
    }
    state = state.copyWith(loading: true, error: null);
    try {
      final d = await _api.fireMe();
      final sites = ((d['sites'] as List?) ?? [])
          .map((e) => FireMarshalSite.fromJson(e as Map<String, dynamic>))
          .toList();
      final active = ((d['active_incidents'] as List?) ?? [])
          .map((e) => FireIncident.fromJson(e as Map<String, dynamic>))
          .toList();
      state = FireState(
        loading: false,
        isMarshal: d['is_marshal'] == true,
        sites: sites,
        activeIncidents: active,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<Map<String, dynamic>> rollCall(int incidentId) =>
      _api.fireRollCall(incidentId);

  Future<void> mark(int incidentId, int personId, String status) =>
      _api.fireMarkRollCall(incidentId, personId, status);

  Future<void> allClear(int incidentId) async {
    await _api.fireAllClear(incidentId);
    await load();
  }

  Future<Map<String, dynamic>> summary(int siteId) =>
      _api.fireMarshalSummary(siteId);
}

final fireProvider = NotifierProvider<FireNotifier, FireState>(FireNotifier.new);
