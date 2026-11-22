import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lincefood_app/features/profile/domain/profile_avatar_repository.dart';
import 'package:lincefood_app/features/profile/domain/avatar_preset.dart';
import 'package:lincefood_app/features/profile/presentation/profile_controller.dart';

void main() {
  test('selecciona y guarda un avatar PNG', () async {
    final image = XFile.fromData(
      Uint8List.fromList([1, 2, 3]),
      name: 'avatar.png',
      mimeType: 'image/png',
    );
    final repository = _FakeAvatarRepository();
    final container = ProviderContainer(
      overrides: [
        avatarImagePickerProvider.overrideWithValue(_FakePicker(image)),
        profileAvatarRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(profileControllerProvider.notifier)
        .seleccionarAvatar('usuario-1');

    expect(repository.savedUid, 'usuario-1');
    expect(repository.savedBytes, [1, 2, 3]);
    expect(repository.savedContentType, 'image/png');
    expect(container.read(profileControllerProvider).errorMessage, isNull);
    expect(container.read(profileControllerProvider).isBusy, isFalse);
  });

  test('rechaza un tipo de imagen no permitido antes de subirlo', () async {
    final image = XFile.fromData(
      Uint8List.fromList([1, 2, 3]),
      name: 'avatar.gif',
      mimeType: 'image/gif',
    );
    final repository = _FakeAvatarRepository();
    final container = ProviderContainer(
      overrides: [
        avatarImagePickerProvider.overrideWithValue(_FakePicker(image)),
        profileAvatarRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(profileControllerProvider.notifier)
        .seleccionarAvatar('usuario-1');

    expect(repository.savedUid, isNull);
    expect(
      container.read(profileControllerProvider).errorMessage,
      contains('JPEG, PNG o WebP'),
    );
  });

  test('elimina el avatar guardado', () async {
    final repository = _FakeAvatarRepository();
    final container = ProviderContainer(
      overrides: [
        profileAvatarRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(profileControllerProvider.notifier)
        .eliminarAvatar('usuario-1');

    expect(repository.removedUid, 'usuario-1');
    expect(container.read(profileControllerProvider).errorMessage, isNull);
  });

  test('guarda el preset seleccionado en el repositorio activo', () async {
    final repository = _FakeAvatarRepository();
    final container = ProviderContainer(
      overrides: [
        profileAvatarRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(profileControllerProvider.notifier)
        .seleccionarPreset('usuario-1', AvatarPreset.linceMasculino);

    expect(repository.presetUid, 'usuario-1');
    expect(repository.savedPreset, 'lince_masculino');
    expect(container.read(profileControllerProvider).errorMessage, isNull);
  });
}

class _FakePicker implements AvatarImagePicker {
  const _FakePicker(this.image);

  final XFile image;

  @override
  Future<XFile?> pickAvatar() async => image;
}

class _FakeAvatarRepository implements ProfileAvatarRepository {
  String? savedUid;
  Uint8List? savedBytes;
  String? savedContentType;
  String? removedUid;
  String? presetUid;
  String? savedPreset;

  @override
  Future<void> saveAvatar(
    String uid,
    Uint8List bytes,
    String contentType,
  ) async {
    savedUid = uid;
    savedBytes = bytes;
    savedContentType = contentType;
  }

  @override
  Future<void> removeAvatar(String uid) async {
    removedUid = uid;
  }

  @override
  Future<void> saveAvatarPreset(String uid, String value) async {
    presetUid = uid;
    savedPreset = value;
  }

  @override
  Stream<String?> watchAvatarPreset(String uid) => Stream.value(savedPreset);
}
