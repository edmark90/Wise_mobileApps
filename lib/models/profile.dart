/// The authenticated user's profile as returned by `GET /users/profile`.
class Profile {
  final String fullname;
  final String email;
  final String phone;
  final String barangay;
  final String zone;
  final String role;
  final String profileImage;

  const Profile({
    this.fullname = '',
    this.email = '',
    this.phone = '',
    this.barangay = '',
    this.zone = '',
    this.role = 'citizen',
    this.profileImage = '',
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    String value(String key) => (json[key] as String?) ?? '';
    return Profile(
      fullname: value('fullname'),
      email: value('email'),
      phone: value('phone'),
      barangay: value('barangay'),
      zone: value('zone'),
      role: value('role').isEmpty ? 'citizen' : value('role'),
      profileImage: value('profile_image'),
    );
  }

  Map<String, dynamic> toJson() => {
        'fullname': fullname,
        'email': email,
        'phone': phone,
        'barangay': barangay,
        'zone': zone,
        'role': role,
        'profile_image': profileImage,
      };

  Profile copyWith({
    String? fullname,
    String? email,
    String? phone,
    String? barangay,
    String? zone,
    String? role,
    String? profileImage,
  }) {
    return Profile(
      fullname: fullname ?? this.fullname,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      barangay: barangay ?? this.barangay,
      zone: zone ?? this.zone,
      role: role ?? this.role,
      profileImage: profileImage ?? this.profileImage,
    );
  }

  String get addressLine {
    if (barangay.isEmpty && zone.isEmpty) return 'Address not set';
    if (barangay.isEmpty) return zone;
    if (zone.isEmpty) return barangay;
    return '$barangay · $zone';
  }

  String get roleLabel => role.isEmpty ? 'CITIZEN' : role.toUpperCase();

  bool get hasPhoto => profileImage.isNotEmpty;
}
