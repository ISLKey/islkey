/// An access-log entry for the user, from GET /islkey/v1/me/log.
class AccessEvent {
  final int id;
  final String eventType; // e.g. "ACCESS_GRANTED", "ACCESS_DENIED"
  final String method; // e.g. "NFC_TAP_CLOUD", "BLE_POCKET_MODE"
  final String result; // "GRANTED" or "DENIED"
  final int doorId;
  final String doorName;
  final DateTime timestamp;

  const AccessEvent({
    required this.id,
    required this.eventType,
    required this.method,
    required this.result,
    required this.doorId,
    required this.doorName,
    required this.timestamp,
  });

  bool get isGranted => result == 'GRANTED';

  static int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  factory AccessEvent.fromJson(Map<String, dynamic> json) {
    return AccessEvent(
      id: _asInt(json['id']),
      eventType: json['event_type'] as String? ?? '',
      method: json['method'] as String? ?? '',
      result: json['result'] as String? ?? '',
      doorId: _asInt(json['door_id']),
      doorName: json['door_name'] as String? ?? 'Door',
      timestamp: DateTime.tryParse(
            ((json['timestamp'] ?? json['created_at']) as String? ?? '')
                .replaceFirst(' ', 'T'),
          ) ??
          DateTime.now(),
    );
  }
}
