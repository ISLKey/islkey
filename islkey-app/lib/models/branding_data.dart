class BrandingData {
  final String customerName;
  final String brandColour;
  final String? logoUrl;

  const BrandingData({
    required this.customerName,
    required this.brandColour,
    this.logoUrl,
  });

  factory BrandingData.fromJson(Map<String, dynamic> json) {
    return BrandingData(
      customerName: json['customer_name'] as String? ?? 'ISLKey',
      brandColour: json['brand_colour'] as String? ?? '#0a2540',
      logoUrl: json['logo_url'] as String?,
    );
  }

  // Fallback ISL defaults before branding loads
  static const BrandingData defaults = BrandingData(
    customerName: 'ISLKey',
    brandColour: '#0a2540',
    logoUrl: null,
  );
}
