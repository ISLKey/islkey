import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/branding_data.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/secure_storage_service.dart';

// ─── Auth state ───────────────────────────────────────────────────────────────

enum AuthStatus { loading, unauthenticated, firstTimeSetup, authenticated }

class AuthState {
  final AuthStatus status;
  final String? token;
  final UserProfile? profile;
  final String? error;

  const AuthState({
    required this.status,
    this.token,
    this.profile,
    this.error,
  });

  const AuthState.loading() : this(status: AuthStatus.loading);
  const AuthState.unauthenticated() : this(status: AuthStatus.unauthenticated);

  bool get isAuthenticated => status == AuthStatus.authenticated;
}

// ─── Provider ─────────────────────────────────────────────────────────────────

class AuthNotifier extends Notifier<AuthState> {
  final _storage = SecureStorageService();

  @override
  AuthState build() {
    _init();
    return const AuthState.loading();
  }

  Future<void> _init() async {
    final token = await _storage.getToken();
    final stored = await _storage.loadProfile();

    final userIdStr = stored['user_id'];
    final userName = stored['user_name'];
    final customerSlug = stored['customer_slug'];
    final apiBase = stored['api_base'];

    UserProfile? profile;
    if (userIdStr != null &&
        userName != null &&
        customerSlug != null &&
        apiBase != null) {
      profile = UserProfile(
        userId: int.tryParse(userIdStr) ?? 0,
        name: userName,
        customerId: int.tryParse(stored['customer_id'] ?? '') ?? 0,
        customerSlug: customerSlug,
        apiBase: apiBase,
        branding: BrandingData(
          customerName: stored['customer_name'] ?? 'ISLKey',
          brandColour: stored['brand_colour'] ?? '#0a2540',
          logoUrl: stored['logo_url'],
        ),
      );
    }

    if (token != null && profile != null) {
      state = AuthState(
        status: AuthStatus.authenticated,
        token: token,
        profile: profile,
      );
    } else {
      // No valid token → show login, but keep the profile (if the device is
      // registered) so PIN sign-in works and branding shows.
      state = AuthState(status: AuthStatus.unauthenticated, profile: profile);
    }
  }

  /// Best-effort branding fetch from ISL Core. Never throws — falls back to the
  /// supplied default so login still succeeds if branding is unavailable.
  Future<BrandingData> _resolveBranding(
      ApiService api, String slug, BrandingData fallback) async {
    if (slug.isEmpty) return fallback;
    try {
      return await api.fetchBranding(slug);
    } catch (_) {
      return fallback;
    }
  }

  /// Accept invitation — stores token and profile on success.
  Future<void> acceptInvitation({
    required String apiBase,
    required String setupCode,
    required String name,
    required String pin,
  }) async {
    final api = ApiService(apiBase: apiBase);
    final data = await api.acceptInvitation(
      setupCode: setupCode,
      pin: pin,
      name: name,
    );

    final token = data['token'] as String;
    final slug = (data['customer_slug'] ?? data['slug']) as String? ?? '';
    final branding = await _resolveBranding(api, slug, BrandingData.defaults);
    final profile = UserProfile.fromJson(data, apiBase, branding: branding);

    await _persist(token: token, profile: profile);
    state = AuthState(
      status: AuthStatus.authenticated,
      token: token,
      profile: profile,
    );
  }

  /// PIN login (returning user).
  Future<void> pinLogin({required String pin}) async {
    final stored = await _storage.loadProfile();
    final customerSlug = stored['customer_slug'];
    final userIdStr = stored['user_id'];
    final apiBase = stored['api_base'];

    if (customerSlug == null || userIdStr == null || apiBase == null) {
      throw const ApiException('No profile found. Please set up the app again.');
    }

    final api = ApiService(apiBase: apiBase);
    final data = await api.login(
      customerSlug: customerSlug,
      userId: int.parse(userIdStr),
      pin: pin,
    );

    final token = data['token'] as String;
    final slug = (data['slug'] ?? data['customer_slug']) as String? ??
        customerSlug;
    // Reuse cached branding as the fallback so we don't flash defaults.
    final cachedBranding = state.profile?.branding ?? BrandingData.defaults;
    final branding = await _resolveBranding(api, slug, cachedBranding);
    final profile = UserProfile.fromJson(data, apiBase, branding: branding);

    await _persist(token: token, profile: profile);
    state = AuthState(
      status: AuthStatus.authenticated,
      token: token,
      profile: profile,
    );
  }

  Future<void> _persist({
    required String token,
    required UserProfile profile,
  }) async {
    await _storage.saveToken(token);
    await _storage.saveProfile(
      userId: profile.userId,
      userName: profile.name,
      customerId: profile.customerId,
      customerSlug: profile.customerSlug,
      apiBase: profile.apiBase,
      brandColour: profile.branding.brandColour,
      customerName: profile.branding.customerName,
      logoUrl: profile.branding.logoUrl,
    );
  }

  Future<void> signOut() async {
    // Keep the device registration/profile so the user can sign back in with
    // their PIN. Only clear the session token — clearing everything would force
    // a fresh (single-use) setup code to re-register.
    await _storage.deleteToken();
    state = AuthState(status: AuthStatus.unauthenticated, profile: state.profile);
  }

  void onTokenExpired() {
    _storage.deleteToken();
    state = AuthState(status: AuthStatus.unauthenticated, profile: state.profile);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
