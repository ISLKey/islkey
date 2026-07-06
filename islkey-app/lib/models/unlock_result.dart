/// Result of resolving an NFC tag, from GET /islkey/v1/tags/resolve.
class TagResolveResult {
  final int doorId;
  final String doorName;
  final int siteId;
  final String siteName;
  final int customerId;
  final String direction; // "entry" or "exit"
  final bool deviceOnline; // ESP32 seen within 120s
  final bool pairedMode;

  const TagResolveResult({
    required this.doorId,
    required this.doorName,
    required this.siteId,
    required this.siteName,
    required this.customerId,
    required this.direction,
    required this.deviceOnline,
    required this.pairedMode,
  });

  static int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  factory TagResolveResult.fromJson(Map<String, dynamic> json) {
    return TagResolveResult(
      doorId: _asInt(json['door_id']),
      doorName: json['door_name'] as String? ?? 'Door',
      siteId: _asInt(json['site_id']),
      siteName: json['site_name'] as String? ?? 'Site',
      customerId: _asInt(json['customer_id']),
      direction: json['direction'] as String? ?? 'entry',
      deviceOnline: json['device_online'] == true,
      pairedMode: json['paired_mode'] == true,
    );
  }
}

/// Result of POST /islkey/v1/doors/{id}/unlock.
class UnlockResult {
  final bool unlocked;
  final String? eventId;
  final bool queued; // true if a device was assigned and the command was queued
  final String doorName;

  const UnlockResult({
    required this.unlocked,
    this.eventId,
    required this.queued,
    required this.doorName,
  });

  factory UnlockResult.fromJson(Map<String, dynamic> json) => UnlockResult(
        unlocked: json['unlocked'] == true,
        eventId: json['event_id'] as String?,
        queued: json['queued'] == true,
        doorName: json['door_name'] as String? ?? 'Door',
      );
}
