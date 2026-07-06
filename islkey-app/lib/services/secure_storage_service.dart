import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/linked_site.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyToken = 'isl_token';
  static const _keyUserId = 'isl_user_id';
  static const _keyUserName = 'isl_user_name';
  static const _keyCustomerId = 'isl_customer_id';
  static const _keyCustomerSlug = 'isl_customer_slug';
  static const _keyApiBase = 'isl_api_base';
  static const _keyBrandColour = 'isl_brand_colour';
  static const _keyLogoUrl = 'isl_logo_url';
  static const _keyCustomerName = 'isl_customer_name';
  static const _keyLinkedSites = 'isl_linked_sites';
  static const _keyDoorsCache = 'isl_doors_cache';
  static const _keyCredentialsCache = 'isl_credentials_cache';

  // ── Token ──
  Future<void> saveToken(String token) =>
      _storage.write(key: _keyToken, value: token);

  Future<String?> getToken() => _storage.read(key: _keyToken);

  Future<void> deleteToken() => _storage.delete(key: _keyToken);

  // ── Profile ──
  Future<void> saveProfile({
    required int userId,
    required String userName,
    required int customerId,
    required String customerSlug,
    required String apiBase,
    required String brandColour,
    required String customerName,
    String? logoUrl,
  }) async {
    await Future.wait([
      _storage.write(key: _keyUserId, value: userId.toString()),
      _storage.write(key: _keyUserName, value: userName),
      _storage.write(key: _keyCustomerId, value: customerId.toString()),
      _storage.write(key: _keyCustomerSlug, value: customerSlug),
      _storage.write(key: _keyApiBase, value: apiBase),
      _storage.write(key: _keyBrandColour, value: brandColour),
      _storage.write(key: _keyCustomerName, value: customerName),
      if (logoUrl != null) _storage.write(key: _keyLogoUrl, value: logoUrl),
    ]);
  }

  Future<Map<String, String?>> loadProfile() async {
    final results = await Future.wait([
      _storage.read(key: _keyUserId),
      _storage.read(key: _keyUserName),
      _storage.read(key: _keyCustomerId),
      _storage.read(key: _keyCustomerSlug),
      _storage.read(key: _keyApiBase),
      _storage.read(key: _keyBrandColour),
      _storage.read(key: _keyLogoUrl),
      _storage.read(key: _keyCustomerName),
    ]);
    return {
      'user_id': results[0],
      'user_name': results[1],
      'customer_id': results[2],
      'customer_slug': results[3],
      'api_base': results[4],
      'brand_colour': results[5],
      'logo_url': results[6],
      'customer_name': results[7],
    };
  }

  // ── Linked sites ──
  Future<void> saveLinkedSites(List<LinkedSite> sites) => _storage.write(
        key: _keyLinkedSites,
        value: jsonEncode(sites.map((s) => s.toJson()).toList()),
      );

  Future<List<LinkedSite>> loadLinkedSites() async {
    final raw = await _storage.read(key: _keyLinkedSites);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => LinkedSite.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  // ── Offline caches (raw JSON lists from /me/doors and /me/credentials) ──
  Future<void> saveDoorsCache(String rawJson) =>
      _storage.write(key: _keyDoorsCache, value: rawJson);

  Future<String?> loadDoorsCache() => _storage.read(key: _keyDoorsCache);

  Future<void> saveCredentialsCache(String rawJson) =>
      _storage.write(key: _keyCredentialsCache, value: rawJson);

  Future<String?> loadCredentialsCache() =>
      _storage.read(key: _keyCredentialsCache);

  Future<void> clearAll() => _storage.deleteAll();
}
