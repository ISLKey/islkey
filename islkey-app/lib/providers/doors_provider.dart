import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/credential.dart';
import '../models/door.dart';
import '../services/api_service.dart';
import '../services/isl_error_codes.dart';
import '../services/secure_storage_service.dart';
import 'auth_provider.dart';

// ─── State ────────────────────────────────────────────────────────────────────

enum DoorsListStatus { loading, ready, error }

/// Drives the unlock flow shown on the scan/result screens.
enum UnlockStatus { idle, scanning, resolving, unlocking, success, error }

class DoorsState {
  final DoorsListStatus listStatus;
  final List<Door> doors;
  final List<Credential> credentials;
  final String? listError;
  final bool fromCache;

  final UnlockStatus unlockStatus;
  final String? unlockDoorName;
  final String? unlockMessage; // success detail e.g. "Unlock sent"
  final String? unlockError;

  const DoorsState({
    this.listStatus = DoorsListStatus.loading,
    this.doors = const [],
    this.credentials = const [],
    this.listError,
    this.fromCache = false,
    this.unlockStatus = UnlockStatus.idle,
    this.unlockDoorName,
    this.unlockMessage,
    this.unlockError,
  });

  DoorsState copyWith({
    DoorsListStatus? listStatus,
    List<Door>? doors,
    List<Credential>? credentials,
    String? listError,
    bool? fromCache,
    UnlockStatus? unlockStatus,
    String? unlockDoorName,
    String? unlockMessage,
    String? unlockError,
  }) {
    return DoorsState(
      listStatus: listStatus ?? this.listStatus,
      doors: doors ?? this.doors,
      credentials: credentials ?? this.credentials,
      listError: listError,
      fromCache: fromCache ?? this.fromCache,
      unlockStatus: unlockStatus ?? this.unlockStatus,
      unlockDoorName: unlockDoorName,
      unlockMessage: unlockMessage,
      unlockError: unlockError,
    );
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

class DoorsNotifier extends Notifier<DoorsState> {
  final _storage = SecureStorageService();

  @override
  DoorsState build() => const DoorsState();

  // Debounce repeated unlock triggers (NFC reader fires several times per tap,
  // stale sessions re-fire). STATIC so it survives notifier recreation.
  static String? _lastKey;
  static DateTime? _lastAt;

  ApiService _api() {
    final authState = ref.read(authProvider);
    final profile = authState.profile;
    if (profile == null) throw const ApiException('Not authenticated.');
    return ApiService(apiBase: profile.apiBase, token: authState.token);
  }

  /// Load the user's doors + credentials from the backend, caching both. On
  /// network failure, falls back to the last cached copy if available.
  Future<void> loadDoors() async {
    state = state.copyWith(listStatus: DoorsListStatus.loading, listError: null);
    try {
      final api = _api();
      final doors = await api.fetchDoors();
      // Credentials are secondary — don't fail the whole load if they error.
      List<Credential> creds = state.credentials;
      try {
        creds = await api.fetchCredentials();
      } catch (_) {/* keep previous/empty */}

      await _cache(doors, creds);
      state = state.copyWith(
        listStatus: DoorsListStatus.ready,
        doors: doors,
        credentials: creds,
        fromCache: false,
      );
    } on TokenExpiredException {
      ref.read(authProvider.notifier).onTokenExpired();
    } on ApiException catch (e) {
      state = state.copyWith(
        listStatus: DoorsListStatus.error,
        listError: e.message,
      );
    } on NetworkException catch (e) {
      // Offline: show cached doors if we have them, otherwise surface the error.
      final cached = await _loadCache();
      if (cached != null && cached.isNotEmpty) {
        state = state.copyWith(
          listStatus: DoorsListStatus.ready,
          doors: cached,
          fromCache: true,
        );
      } else {
        state = state.copyWith(
          listStatus: DoorsListStatus.error,
          listError: e.message,
        );
      }
    } catch (_) {
      state = state.copyWith(
        listStatus: DoorsListStatus.error,
        listError: 'Could not load your doors. Please try again.',
      );
    }
  }

  Future<void> _cache(List<Door> doors, List<Credential> creds) async {
    await _storage.saveDoorsCache(
        jsonEncode(doors.map((d) => d.toJson()).toList()));
    await _storage.saveCredentialsCache(
        jsonEncode(creds.map((c) => c.toJson()).toList()));
  }

  Future<List<Door>?> _loadCache() async {
    final raw = await _storage.loadDoorsCache();
    if (raw == null || raw.isEmpty) return null;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => Door.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return null;
    }
  }

  Door? doorById(int id) {
    for (final d in state.doors) {
      if (d.id == id) return d;
    }
    return null;
  }

  // ── Unlock flow ─────────────────────────────────────────────────────────────

  void startScanning() {
    state = state.copyWith(unlockStatus: UnlockStatus.scanning);
  }

  void cancelScanning() {
    state = state.copyWith(unlockStatus: UnlockStatus.idle);
  }

  void reset() {
    state = state.copyWith(unlockStatus: UnlockStatus.idle);
  }

  bool _debounced(String key) {
    final now = DateTime.now();
    if (_lastKey == key &&
        _lastAt != null &&
        now.difference(_lastAt!) < const Duration(seconds: 6)) {
      return true;
    }
    _lastKey = key;
    _lastAt = now;
    return false;
  }

  void _clearDebounce() {
    _lastKey = null;
    _lastAt = null;
  }

  /// Primary flow: NFC tag tapped → resolve to a door → verify access → unlock.
  /// Returns true if an attempt was made (navigate to the result screen), false
  /// if the read was a debounced duplicate (just dismiss).
  Future<bool> resolveAndUnlock(String rawUid) async {
    final uid = rawUid.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').toUpperCase();
    if (_debounced('tag:$uid')) return false;

    state = state.copyWith(unlockStatus: UnlockStatus.resolving);
    try {
      final tag = await _api().resolveTag(uid);

      // Verify the user actually has this door in their credential list.
      final door = doorById(tag.doorId);
      if (door == null) {
        _fail('You do not have access to this door.', doorName: tag.doorName);
        return true;
      }
      if (door.fireAlarmActive) {
        _fail('Fire alarm active — this door cannot be unlocked.',
            doorName: door.doorName);
        return true;
      }

      state = state.copyWith(
        unlockStatus: UnlockStatus.unlocking,
        unlockDoorName: tag.doorName,
      );
      final result =
          await _api().unlockDoor(tag.doorId, method: 'NFC_TAP_CLOUD');
      _succeed(result.doorName, result.queued);
      return true;
    } on TokenExpiredException {
      _clearDebounce();
      ref.read(authProvider.notifier).onTokenExpired();
      return false;
    } on ApiException catch (e) {
      _clearDebounce();
      _fail(_resolveErrorMessage(e));
      return true;
    } on NetworkException catch (e) {
      _clearDebounce();
      _fail(e.message);
      return true;
    } catch (_) {
      _clearDebounce();
      _fail('Something went wrong. Please try again.');
      return true;
    }
  }

  /// Direct unlock from a door card (no NFC tap). Returns true if attempted.
  Future<bool> unlockDoorDirect(Door door) async {
    if (_debounced('door:${door.id}')) return false;

    state = state.copyWith(
      unlockStatus: UnlockStatus.unlocking,
      unlockDoorName: door.doorName,
    );
    try {
      final result = await _api().unlockDoor(door.id);
      _succeed(result.doorName, result.queued);
      return true;
    } on TokenExpiredException {
      _clearDebounce();
      ref.read(authProvider.notifier).onTokenExpired();
      return false;
    } on ApiException catch (e) {
      _clearDebounce();
      _fail(_unlockErrorMessage(e), doorName: door.doorName);
      return true;
    } on NetworkException catch (e) {
      _clearDebounce();
      _fail(e.message, doorName: door.doorName);
      return true;
    } catch (_) {
      _clearDebounce();
      _fail('Something went wrong. Please try again.', doorName: door.doorName);
      return true;
    }
  }

  void _succeed(String doorName, bool queued) {
    state = state.copyWith(
      unlockStatus: UnlockStatus.success,
      unlockDoorName: doorName,
      unlockMessage: queued
          ? 'Unlock sent — the door will open shortly.'
          : 'Unlock recorded, but no controller is fitted to this door.',
    );
  }

  void _fail(String message, {String? doorName}) {
    state = state.copyWith(
      unlockStatus: UnlockStatus.error,
      unlockDoorName: doorName,
      unlockError: message,
    );
  }

  String _resolveErrorMessage(ApiException e) {
    final mapped = IslErrorCodes.messageFor(e.code);
    if (mapped != null) return mapped;
    switch (e.statusCode) {
      case 404:
        return "This tag isn't registered. Please contact your system manager.";
      case 403:
        return 'This tag has been disabled.';
      default:
        return _unlockErrorMessage(e);
    }
  }

  String _unlockErrorMessage(ApiException e) {
    final mapped = IslErrorCodes.messageFor(e.code);
    if (mapped != null) return mapped;
    switch (e.statusCode) {
      case 403:
        return 'You do not have a valid credential for this door.';
      case 404:
        return 'Door not found.';
      case 422:
        return 'Fire alarm active — this door cannot be unlocked.';
      default:
        return e.message;
    }
  }
}

final doorsProvider =
    NotifierProvider<DoorsNotifier, DoorsState>(DoorsNotifier.new);
