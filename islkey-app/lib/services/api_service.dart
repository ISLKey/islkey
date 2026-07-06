import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/access_event.dart';
import '../models/branding_data.dart';
import '../models/credential.dart';
import '../models/door.dart';
import '../models/linked_site.dart';
import '../models/unlock_result.dart';

// ─── Custom exceptions ────────────────────────────────────────────────────────

class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final String? code;

  const ApiException(this.message, {this.statusCode, this.code});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class NetworkException implements Exception {
  final String message;
  const NetworkException(this.message);
}

class TokenExpiredException implements Exception {}

// ─── Dev HTTP override ────────────────────────────────────────────────────────

class _DevHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) => true;
  }
}

void configureHttpForDebug() {
  if (kDebugMode) {
    HttpOverrides.global = _DevHttpOverrides();
  }
}

// ─── ApiService ───────────────────────────────────────────────────────────────
//
// ISLKey backend convention (ISL Core): every endpoint returns
//   success: { "ok": true,  "data": { ... } }
//   error:   { "ok": false, "code": "...", "message": "..." }
// so _handleResponse unwraps `data` on success and reads code/message on error.

class ApiService {
  final String apiBase;
  final String? token;

  ApiService({required this.apiBase, this.token});

  String _url(String path) {
    final base = apiBase.endsWith('/') ? apiBase : '$apiBase/';
    final clean = path.startsWith('/') ? path.substring(1) : path;
    return '$base$clean';
  }

  Map<String, String> _headers({bool requireAuth = true}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (requireAuth && token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // Fallback for servers that strip the Authorization header.
  String _tokenParam() => token != null ? '?_isl_token=$token' : '';

  /// Returns the unwrapped `data` object on success. Throws on error/401.
  Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    if (response.statusCode == 401) throw TokenExpiredException();

    late Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('Unexpected server response',
          statusCode: response.statusCode);
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = body['data'];
      if (data is Map<String, dynamic>) return data;
      // Some endpoints (or ISL Core branding) may return the payload at the top
      // level — fall back to the body so callers still get their fields.
      return body;
    }

    final code = body['code'] as String?;
    final message = body['message'] as String? ?? 'An error occurred.';
    throw ApiException(message, statusCode: response.statusCode, code: code);
  }

  Future<T> _run<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on SocketException {
      throw const NetworkException(
          'No internet connection. Please check your signal and try again.');
    } on HttpException {
      throw const NetworkException(
          'No internet connection. Please check your signal and try again.');
    } on TimeoutException {
      throw const NetworkException('Connection timed out. Please try again.');
    } on TokenExpiredException {
      rethrow;
    } on ApiException {
      rethrow;
    } on NetworkException {
      rethrow;
    } catch (_) {
      throw const NetworkException(
          'Something went wrong. Please try again or contact your system manager.');
    }
  }

  // ── Branding (ISL Core, shared across the ISL ecosystem) ──────────────────

  Future<BrandingData> fetchBranding(String customerSlug) => _run(() async {
        final url = _url('isl/v1/branding/$customerSlug');
        final response = await http
            .get(Uri.parse(url), headers: _headers(requireAuth: false))
            .timeout(const Duration(seconds: 10));
        final body = await _handleResponse(response);
        return BrandingData.fromJson(body);
      });

  // ── Auth ──────────────────────────────────────────────────────────────────

  /// First-time setup. Returns the raw `data` object (caller reads the token).
  Future<Map<String, dynamic>> acceptInvitation({
    required String setupCode,
    required String pin,
    required String name,
  }) =>
      _run(() async {
        final url = _url('islkey/v1/invite/accept');
        final response = await http
            .post(
              Uri.parse(url),
              headers: _headers(requireAuth: false),
              body: jsonEncode({'token': setupCode, 'pin': pin, 'name': name}),
            )
            .timeout(const Duration(seconds: 15));
        return _handleResponse(response);
      });

  /// Re-authentication for a returning user.
  Future<Map<String, dynamic>> login({
    required String customerSlug,
    required int userId,
    required String pin,
  }) =>
      _run(() async {
        final url = _url('islkey/v1/auth');
        final response = await http
            .post(
              Uri.parse(url),
              headers: _headers(requireAuth: false),
              body: jsonEncode({
                'customer_slug': customerSlug,
                'user_id': userId,
                'pin': pin,
              }),
            )
            .timeout(const Duration(seconds: 10));
        return _handleResponse(response);
      });

  /// Link an additional site by its code.
  Future<LinkSiteResult> linkSite({required String siteCode}) => _run(() async {
        final url = _url('islkey/v1/site/link${_tokenParam()}');
        final response = await http
            .post(
              Uri.parse(url),
              headers: _headers(),
              body: jsonEncode({'site_code': siteCode}),
            )
            .timeout(const Duration(seconds: 10));
        final body = await _handleResponse(response);
        return LinkSiteResult.fromJson(body);
      });

  // ── Doors / credentials / log ───────────────────────────────────────────────

  Future<List<Door>> fetchDoors() => _run(() async {
        final url = _url('islkey/v1/me/doors${_tokenParam()}');
        final response = await http
            .get(Uri.parse(url), headers: _headers())
            .timeout(const Duration(seconds: 10));
        final body = await _handleResponse(response);
        final doors = body['doors'] as List<dynamic>? ?? [];
        return doors
            .map((d) => Door.fromJson(d as Map<String, dynamic>))
            .toList();
      });

  Future<List<Credential>> fetchCredentials() => _run(() async {
        final url = _url('islkey/v1/me/credentials${_tokenParam()}');
        final response = await http
            .get(Uri.parse(url), headers: _headers())
            .timeout(const Duration(seconds: 10));
        final body = await _handleResponse(response);
        final creds = body['credentials'] as List<dynamic>? ?? [];
        return creds
            .map((c) => Credential.fromJson(c as Map<String, dynamic>))
            .toList();
      });

  Future<List<AccessEvent>> fetchLog() => _run(() async {
        final url = _url('islkey/v1/me/log${_tokenParam()}');
        final response = await http
            .get(Uri.parse(url), headers: _headers())
            .timeout(const Duration(seconds: 10));
        final body = await _handleResponse(response);
        final events = body['events'] as List<dynamic>? ?? [];
        return events
            .map((e) => AccessEvent.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  // ── Unlock flow ─────────────────────────────────────────────────────────────

  /// Resolve an NFC tag UID (uppercase hex, no colons) to its door + site.
  Future<TagResolveResult> resolveTag(String serial) => _run(() async {
        final url = _url('islkey/v1/tags/resolve?serial=$serial');
        final response = await http
            .get(Uri.parse(url), headers: _headers(requireAuth: false))
            .timeout(const Duration(seconds: 10));
        final body = await _handleResponse(response);
        return TagResolveResult.fromJson(body);
      });

  /// Request an unlock for a door. The backend validates the credential, queues
  /// an UNLOCK command to the ESP32, and logs the access event.
  Future<UnlockResult> unlockDoor(int doorId, {String? method}) =>
      _run(() async {
        final url = _url('islkey/v1/doors/$doorId/unlock${_tokenParam()}');
        final response = await http
            .post(
              Uri.parse(url),
              headers: _headers(),
              body: jsonEncode({if (method != null) 'method': method}),
            )
            .timeout(const Duration(seconds: 10));
        final body = await _handleResponse(response);
        return UnlockResult.fromJson(body);
      });

  // ── ISLFire (Fire Marshal module) ───────────────────────────────────────────

  /// The logged-in user's fire-marshal status + any active incidents on their
  /// sites. Drives whether the Fire tab is shown and whether to open evacuation.
  Future<Map<String, dynamic>> fireMe() => _run(() async {
        final url = _url('islfire/v1/me${_tokenParam()}');
        final response = await http
            .get(Uri.parse(url), headers: _headers())
            .timeout(const Duration(seconds: 10));
        return _handleResponse(response);
      });

  /// Roll call for an active incident — { session, roll_call, panel_clear }.
  Future<Map<String, dynamic>> fireRollCall(int incidentId) => _run(() async {
        final url =
            _url('islfire/v1/incidents/$incidentId/rollcall${_tokenParam()}');
        final response = await http
            .get(Uri.parse(url), headers: _headers())
            .timeout(const Duration(seconds: 10));
        return _handleResponse(response);
      });

  /// Mark a person safe / missing / injury during evacuation.
  Future<Map<String, dynamic>> fireMarkRollCall(
          int incidentId, int personId, String status) =>
      _run(() async {
        final url = _url(
            'islfire/v1/incidents/$incidentId/rollcall/$personId${_tokenParam()}');
        final response = await http
            .post(Uri.parse(url),
                headers: _headers(), body: jsonEncode({'status': status}))
            .timeout(const Duration(seconds: 10));
        return _handleResponse(response);
      });

  /// Confirm evacuation complete (server gates this until the panel has reset).
  Future<Map<String, dynamic>> fireAllClear(int incidentId) => _run(() async {
        final url =
            _url('islfire/v1/incidents/$incidentId/allclear${_tokenParam()}');
        final response = await http
            .post(Uri.parse(url), headers: _headers())
            .timeout(const Duration(seconds: 10));
        return _handleResponse(response);
      });

  /// Normal-state summary for a site — { marshals, schedule, last_drills }.
  Future<Map<String, dynamic>> fireMarshalSummary(int siteId) => _run(() async {
        final sep = _tokenParam().isEmpty ? '?' : '&';
        final url = _url(
            'islfire/v1/marshal/summary${_tokenParam()}${sep}site_id=$siteId');
        final response = await http
            .get(Uri.parse(url), headers: _headers())
            .timeout(const Duration(seconds: 10));
        return _handleResponse(response);
      });
}
