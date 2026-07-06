import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/linked_site.dart';
import '../services/api_service.dart';
import '../services/secure_storage_service.dart';
import 'auth_provider.dart';

/// Holds the additional sites the user has linked (beyond their primary
/// account). Loaded from secure storage; updated when a new site is linked.
class SitesNotifier extends Notifier<List<LinkedSite>> {
  final _storage = SecureStorageService();

  @override
  List<LinkedSite> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    state = await _storage.loadLinkedSites();
  }

  /// Calls POST /site/link and, on success, stores the site locally.
  /// Throws ApiException / NetworkException on failure for the UI to handle.
  Future<LinkSiteResult> link(String siteCode) async {
    final authState = ref.read(authProvider);
    final profile = authState.profile;
    if (profile == null) {
      throw const ApiException('Not authenticated.');
    }
    final api = ApiService(apiBase: profile.apiBase, token: authState.token);
    final result = await api.linkSite(siteCode: siteCode);

    if (!state.any((s) => s.siteId == result.site.siteId)) {
      final updated = [...state, result.site];
      await _storage.saveLinkedSites(updated);
      state = updated;
    }
    return result;
  }
}

final sitesProvider =
    NotifierProvider<SitesNotifier, List<LinkedSite>>(SitesNotifier.new);
