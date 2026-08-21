/// Admin/backend-managed company office.
/// Flutter must not hardcode a second address; this is the shared config object
/// that production will load from Admin. Values below are placeholders from
/// existing Admin `company.js` — REQUIRES BUSINESS CONFIGURATION before launch.
class CompanyOffice {
  const CompanyOffice({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String name;
  final String address;
  final String city;
  final double? latitude;
  final double? longitude;

  static const CompanyOffice ahmedabadPlaceholder = CompanyOffice(
    id: 'office_amd',
    name: 'Ahmedabad Company Office',
    address:
        '4th Floor, Sunrise Corporate Park, SG Highway, Ahmedabad 380054, Gujarat',
    city: 'Ahmedabad',
    latitude: 23.0470,
    longitude: 72.5310,
  );

  /// Live Admin-configured office. Defaults to the Ahmedabad seed until Admin saves.
  static CompanyOffice current = ahmedabadPlaceholder;

  factory CompanyOffice.fromJson(Map<String, dynamic> json) {
    return CompanyOffice(
      id: json['id'] as String? ?? 'office_amd',
      name: json['name'] as String? ?? 'Company Office',
      address: json['address'] as String? ?? '',
      city: json['city'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'address': address,
        'city': city,
        'latitude': latitude,
        'longitude': longitude,
      };
}
