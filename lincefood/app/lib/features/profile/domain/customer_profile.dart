class CustomerProfile {
  const CustomerProfile({
    required this.id,
    required this.name,
    required this.email,
    this.provider = 'password',
    this.providerPhotoUrl,
    this.hasCustomPhoto = false,
  });

  final String id;
  final String name;
  final String email;
  final String provider;
  final String? providerPhotoUrl;
  final bool hasCustomPhoto;
}
