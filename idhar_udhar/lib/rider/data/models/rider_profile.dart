/// Rider profile domain model (API-ready).
class RiderProfile {
  const RiderProfile({
    required this.id,
    required this.name,
    required this.mobile,
    required this.email,
    required this.dateOfBirth,
    required this.language,
    this.photoUrl,
    this.rating = 4.9,
  });

  final String id;
  final String name;
  final String mobile;
  final String email;
  final DateTime dateOfBirth;
  final String language;
  final String? photoUrl;
  final double rating;

  String get firstName {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? name : parts.first;
  }

  RiderProfile copyWith({
    String? id,
    String? name,
    String? mobile,
    String? email,
    DateTime? dateOfBirth,
    String? language,
    String? photoUrl,
    double? rating,
  }) {
    return RiderProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      language: language ?? this.language,
      photoUrl: photoUrl ?? this.photoUrl,
      rating: rating ?? this.rating,
    );
  }
}
