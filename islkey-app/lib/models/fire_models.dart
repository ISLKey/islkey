// ISLFire (Fire Marshal module) models. The app authenticates as an ISLKey
// user; fire-marshal status is resolved server-side via the linked person.

int _asInt(dynamic v) => v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;

/// A site this user is a fire marshal / warden for.
class FireMarshalSite {
  final int siteId;
  final String siteName;
  final String role; // fire_marshal | fire_warden
  final String? zone;

  const FireMarshalSite({
    required this.siteId,
    required this.siteName,
    required this.role,
    this.zone,
  });

  bool get isMarshal => role == 'fire_marshal';

  factory FireMarshalSite.fromJson(Map<String, dynamic> j) => FireMarshalSite(
        siteId: _asInt(j['site_id']),
        siteName: (j['site_name'] as String?) ?? 'Site #${_asInt(j['site_id'])}',
        role: (j['role'] as String?) ?? 'fire_marshal',
        zone: j['zone'] as String?,
      );
}

/// An active or historical fire incident / drill / test.
class FireIncident {
  final int id;
  final int siteId;
  final String incidentType; // fire_alarm | drill | test
  final String? triggeredAt;
  final String? allClearAt;

  const FireIncident({
    required this.id,
    required this.siteId,
    required this.incidentType,
    this.triggeredAt,
    this.allClearAt,
  });

  bool get isDrill => incidentType == 'drill';
  bool get isActive => allClearAt == null;

  factory FireIncident.fromJson(Map<String, dynamic> j) => FireIncident(
        id: _asInt(j['id']),
        siteId: _asInt(j['site_id']),
        incidentType: (j['incident_type'] as String?) ?? 'fire_alarm',
        triggeredAt: j['triggered_at'] as String?,
        allClearAt: j['all_clear_at'] as String?,
      );

  /// Minutes since the alarm triggered (triggered_at is stored UTC).
  int get elapsedMinutes {
    if (triggeredAt == null) return 0;
    final t = DateTime.tryParse('${triggeredAt!.replaceFirst(' ', 'T')}Z');
    if (t == null) return 0;
    final m = DateTime.now().toUtc().difference(t.toUtc()).inMinutes;
    return m < 0 ? 0 : m;
  }
}

/// One person on the evacuation roll call.
class RollCallEntry {
  final int personId;
  final String name;
  final String? department;
  final String status; // unaccounted | safe | missing | injury

  const RollCallEntry({
    required this.personId,
    required this.name,
    this.department,
    required this.status,
  });

  factory RollCallEntry.fromJson(Map<String, dynamic> j) => RollCallEntry(
        personId: _asInt(j['person_id']),
        name: (j['full_name'] as String?) ?? 'Person #${_asInt(j['person_id'])}',
        department: j['department'] as String?,
        status: (j['status'] as String?) ?? 'unaccounted',
      );
}
