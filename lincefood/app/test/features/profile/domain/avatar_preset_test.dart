import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/profile/domain/avatar_preset.dart';
import 'package:lincefood_app/features/profile/domain/customer_profile.dart';

void main() {
  test('usa personaje neutro cuando no hay selección guardada', () {
    expect(
      resolverPresetVisible(savedPreset: null, hasUploadedPhoto: false),
      AvatarPreset.neutro,
    );
  });

  test('conserva la selección manual disponible', () {
    expect(
      resolverPresetVisible(
        savedPreset: 'lince_masculino',
        hasUploadedPhoto: false,
      ),
      AvatarPreset.linceMasculino,
    );
  });

  test('la foto subida tiene prioridad sobre el preset', () {
    expect(
      resolverPresetVisible(
        savedPreset: 'lince_masculino',
        hasUploadedPhoto: true,
      ),
      AvatarPreset.neutro,
    );
  });

  test('todos los avatares tienen imagen y están disponibles', () {
    for (final preset in AvatarPreset.values) {
      expect(preset.available, isTrue);
      expect(preset.assetPath, startsWith('assets/avatars/'));
    }
  });

  test('prepara la escritura RTDB del preset seleccionado', () {
    expect(avatarPresetUpdate('lince_masculino'), {
      'avatarPreset': 'lince_masculino',
    });
    expect(() => avatarPresetUpdate('inventado'), throwsArgumentError);
  });
}
