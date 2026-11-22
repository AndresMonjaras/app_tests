import 'package:flutter/material.dart';

enum AvatarPreset {
  neutro('neutro', 'Personaje neutro', 'assets/avatars/personaje_neutro.webp'),
  linceMasculino(
    'lince_masculino',
    'Lince masculino',
    'assets/avatars/lince_masculino.webp',
  ),
  linceFemenino(
    'lince_femenino',
    'Lince femenino',
    'assets/avatars/lince_femenino.webp',
  );

  const AvatarPreset(this.value, this.label, this.assetPath);

  final String value;
  final String label;
  final String? assetPath;

  bool get available => assetPath != null;

  static AvatarPreset fromValue(String? value) {
    for (final preset in values) {
      if (preset.value == value) return preset;
    }
    return neutro;
  }
}

AvatarPreset resolverPresetVisible({
  required String? savedPreset,
  required bool hasUploadedPhoto,
}) {
  if (hasUploadedPhoto) return AvatarPreset.neutro;
  return AvatarPreset.fromValue(savedPreset);
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    required this.preset,
    this.photoUrl,
    this.radius = 44,
    super.key,
  });

  final AvatarPreset preset;
  final String? photoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final assetPath = preset.assetPath;
    return CircleAvatar(
      radius: radius,
      foregroundImage: photoUrl == null ? null : NetworkImage(photoUrl!),
      backgroundImage: assetPath == null ? null : AssetImage(assetPath),
      child: assetPath == null
          ? Icon(Icons.person_outline, size: radius)
          : null,
    );
  }
}
