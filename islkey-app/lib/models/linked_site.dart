/// A site the user has linked in addition to their primary account. Unlocking
/// works at any linked site using the same token + PIN; the door is determined
/// by the NFC tag tapped. Linked via POST /islkey/v1/site/link.
class LinkedSite {
  final int siteId;
  final String siteName;
  final int customerId;

  const LinkedSite({
    required this.siteId,
    required this.siteName,
    required this.customerId,
  });

  Map<String, dynamic> toJson() => {
        'site_id': siteId,
        'site_name': siteName,
        'customer_id': customerId,
      };

  factory LinkedSite.fromJson(Map<String, dynamic> json) => LinkedSite(
        siteId: _asInt(json['site_id']),
        siteName: json['site_name'] as String? ?? 'Site',
        customerId: _asInt(json['customer_id']),
      );
}

/// Result of POST /site/link.
class LinkSiteResult {
  final LinkedSite site;
  final String message;

  const LinkSiteResult({required this.site, required this.message});

  factory LinkSiteResult.fromJson(Map<String, dynamic> json) => LinkSiteResult(
        site: LinkedSite.fromJson(json),
        message: json['message'] as String? ?? 'Site linked successfully.',
      );
}

/// Parse an int the backend may send as a JSON number or string.
int _asInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
