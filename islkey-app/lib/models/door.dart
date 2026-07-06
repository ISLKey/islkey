/// A door the user holds an active credential for, as returned by
/// GET /islkey/v1/me/doors.
class Door {
  final int id;
  final String doorName;
  final int siteId;
  final String? description;
  final String direction; // "entry", "exit", or "both"
  final String status; // "active" or "inactive"
  final String mode; // "single" or "paired"
  final String? deviceStatus; // "active", "inactive", or null (no device)
  final DateTime? lastSeen;
  final String relay1State; // "OPEN" or "CLOSED"
  final String? doorContactState; // "OPEN", "CLOSED", or null
  final String fireAlarmState; // "NORMAL" or "ACTIVE"
  final String? deviceUuid; // null = no controller fitted

  const Door({
    required this.id,
    required this.doorName,
    required this.siteId,
    this.description,
    required this.direction,
    required this.status,
    required this.mode,
    this.deviceStatus,
    this.lastSeen,
    required this.relay1State,
    this.doorContactState,
    required this.fireAlarmState,
    this.deviceUuid,
  });

  /// True if a controller is fitted (an ESP32 is assigned to this door).
  bool get hasController => deviceUuid != null && deviceUuid!.isNotEmpty;

  /// True if the controller is reporting as active/online.
  bool get isOnline => deviceStatus == 'active';

  /// True if the door is currently in fire-alarm state — unlock is blocked.
  bool get fireAlarmActive => fireAlarmState == 'ACTIVE';

  /// Whether the unlock button should be enabled. The backend is the final
  /// authority (it re-checks on /unlock), but this avoids obviously-doomed taps.
  bool get canUnlock =>
      status == 'active' && hasController && !fireAlarmActive;

  static int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _asDate(dynamic value) {
    final raw = value as String?;
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw.replaceFirst(' ', 'T'));
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'door_name': doorName,
        'site_id': siteId,
        'description': description,
        'direction': direction,
        'status': status,
        'mode': mode,
        'device_status': deviceStatus,
        'last_seen': lastSeen?.toIso8601String(),
        'relay_1_state': relay1State,
        'door_contact_state': doorContactState,
        'fire_alarm_state': fireAlarmState,
        'device_uuid': deviceUuid,
      };

  factory Door.fromJson(Map<String, dynamic> json) {
    return Door(
      id: _asInt(json['id']),
      doorName: json['door_name'] as String? ?? 'Door',
      siteId: _asInt(json['site_id']),
      description: json['description'] as String?,
      direction: json['direction'] as String? ?? 'both',
      status: json['status'] as String? ?? 'active',
      mode: json['mode'] as String? ?? 'single',
      deviceStatus: json['device_status'] as String?,
      lastSeen: _asDate(json['last_seen']),
      relay1State: json['relay_1_state'] as String? ?? 'CLOSED',
      doorContactState: json['door_contact_state'] as String?,
      fireAlarmState: json['fire_alarm_state'] as String? ?? 'NORMAL',
      deviceUuid: json['device_uuid'] as String?,
    );
  }
}
