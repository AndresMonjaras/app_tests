class CustomerProfile {
  const CustomerProfile({
    required this.id,
    required this.name,
    required this.email,
    this.provider = 'password',
    this.providerPhotoUrl,
    this.hasCustomPhoto = false,
    this.avatarPreset = 'neutro',
  });

  final String id;
  final String name;
  final String email;
  final String provider;
  final String? providerPhotoUrl;
  final bool hasCustomPhoto;
  final String avatarPreset;
}

Map<String, String> avatarPresetUpdate(String preset) {
  const presets = {'neutro', 'lince_masculino', 'lince_femenino'};
  if (!presets.contains(preset)) {
    throw ArgumentError.value(preset, 'preset');
  }
  return {'avatarPreset': preset};
}
