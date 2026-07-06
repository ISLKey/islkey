import 'branding_data.dart';

/// The authenticated ISLKey user (door holder). ISLKey users live in the
/// islkey_users table and authenticate with customer_slug + user_id + PIN —
/// they are NOT WordPress users.
class UserProfile {
  final int userId;
  final String name;
  final int customerId;
  final String customerSlug;
  final String apiBase;
  final BrandingData branding;

  const UserProfile({
    required this.userId,
    required this.name,
    required this.customerId,
    required this.customerSlug,
    required this.apiBase,
    required this.branding,
  });

  /// Parse an int the backend may send as either a JSON number or string
  /// (e.g. customer_id arrives as "1"). Avoids a hard `as int` cast that throws.
  static int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  /// Builds a profile from an /auth or /invite/accept response `data` object.
  /// The re-auth response calls the slug field `slug`; invite/accept calls it
  /// `customer_slug` — accept either. Branding is fetched separately (ISL Core),
  /// so callers pass it in once resolved.
  factory UserProfile.fromJson(
    Map<String, dynamic> json,
    String apiBase, {
    BrandingData? branding,
  }) {
    return UserProfile(
      userId: _asInt(json['user_id']),
      name: json['name'] as String? ?? 'User',
      customerId: _asInt(json['customer_id']),
      customerSlug: (json['customer_slug'] ?? json['slug']) as String? ?? '',
      apiBase: apiBase,
      branding: branding ?? BrandingData.defaults,
    );
  }

  UserProfile copyWith({BrandingData? branding}) => UserProfile(
        userId: userId,
        name: name,
        customerId: customerId,
        customerSlug: customerSlug,
        apiBase: apiBase,
        branding: branding ?? this.branding,
      );
}
