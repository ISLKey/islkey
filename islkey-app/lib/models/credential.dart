import 'dart:convert';

/// An active credential for the user, from GET /islkey/v1/me/credentials.
/// Cached locally alongside /me/doors (used for offline / future BLE fallback).
class Credential {
  final int id;
  final List<int> doorIds;
  final String credentialType; // "ISLKEY_APP", "NFC_CARD", or "KEYFOB"
  final int? scheduleId; // null = always valid
  final DateTime? validFrom;
  final DateTime? validUntil;
  final String status;

  const Credential({
    required this.id,
    required this.doorIds,
    required this.credentialType,
    this.scheduleId,
    this.validFrom,
    this.validUntil,
    required this.status,
  });

  static int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _asDate(dynamic value) {
    final raw = value as String?;
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw.replaceFirst(' ', 'T'));
  }

  /// door_ids_json arrives as a JSON array *string* e.g. "[3,4]".
  static List<int> _parseDoorIds(dynamic value) {
    if (value is List) return value.map(_asInt).toList();
    if (value is String && value.isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) return decoded.map(_asInt).toList();
      } catch (_) {/* fall through */}
    }
    return const [];
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'door_ids_json': jsonEncode(doorIds),
        'credential_type': credentialType,
        'schedule_id': scheduleId,
        'valid_from': validFrom?.toIso8601String(),
        'valid_until': validUntil?.toIso8601String(),
        'status': status,
      };

  factory Credential.fromJson(Map<String, dynamic> json) {
    return Credential(
      id: _asInt(json['id']),
      doorIds: _parseDoorIds(json['door_ids_json']),
      credentialType: json['credential_type'] as String? ?? 'ISLKEY_APP',
      scheduleId: json['schedule_id'] == null ? null : _asInt(json['schedule_id']),
      validFrom: _asDate(json['valid_from']),
      validUntil: _asDate(json['valid_until']),
      status: json['status'] as String? ?? 'active',
    );
  }
}
