import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/presentation/auth_controller.dart';
import '../../media/domain/media_upload_validator.dart';
import '../../media/domain/private_avatar_cache.dart';
import '../../media/presentation/media_storage_provider.dart';
import '../data/firebase_profile_avatar_repository.dart';
import '../data/firebase_profile_repository.dart';
import '../domain/avatar_preset.dart';
import '../domain/profile_avatar_repository.dart';

abstract interface class AvatarImagePicker {
  Future<XFile?> pickAvatar();
}

class GalleryAvatarImagePicker implements AvatarImagePicker {
  GalleryAvatarImagePicker([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<XFile?> pickAvatar() => _picker.pickImage(
    source: ImageSource.gallery,
    maxWidth: 1024,
    maxHeight: 1024,
    imageQuality: 85,
  );
}

final privateAvatarCacheProvider = Provider<PrivateAvatarCache>(
  (ref) => FlutterPrivateAvatarCache(),
);

final avatarImagePickerProvider = Provider<AvatarImagePicker>(
  (ref) => GalleryAvatarImagePicker(),
);

final profileAvatarRepositoryProvider = Provider<ProfileAvatarRepository>((
  ref,
) {
  return FirebaseProfileAvatarRepository(
    authentication: ref.watch(firebaseAuthProvider),
    database: FirebaseDatabase.instance,
    mediaStorage: ref.watch(mediaStorageProvider),
  );
});

final avatarPresetProvider = StreamProvider.autoDispose.family<String?, String>(
  (ref, uid) =>
      ref.watch(profileAvatarRepositoryProvider).watchAvatarPreset(uid),
);

final currentAvatarPresetProvider = Provider.autoDispose<AvatarPreset>((ref) {
  final uid = ref.watch(authUserProvider).asData?.value?.uid;
  if (uid == null) return AvatarPreset.neutro;
  final preset = ref.watch(avatarPresetProvider(uid)).asData?.value;
  return AvatarPreset.fromValue(preset);
});

class ProfileAvatarState {
  const ProfileAvatarState({this.isBusy = false, this.errorMessage});

  final bool isBusy;
  final String? errorMessage;
}

class ProfileController extends Notifier<ProfileAvatarState> {
  @override
  ProfileAvatarState build() => const ProfileAvatarState();

  Future<void> seleccionarAvatar(String uid) async {
    if (state.isBusy) return;
    state = const ProfileAvatarState(isBusy: true);

    try {
      final image = await ref.read(avatarImagePickerProvider).pickAvatar();
      if (image == null) {
        if (ref.mounted) state = const ProfileAvatarState();
        return;
      }

      final bytes = await image.readAsBytes();
      final contentType = _contentTypeFor(image);
      MediaUploadValidator.validate(bytes, contentType);
      await ref
          .read(profileAvatarRepositoryProvider)
          .saveAvatar(uid, bytes, contentType);
      ref.invalidate(customerProfileProvider);
      ref.invalidate(avatarEligibilityProvider);
      if (ref.mounted) state = const ProfileAvatarState();
    } on ArgumentError {
      if (ref.mounted) {
        state = const ProfileAvatarState(
          errorMessage: 'Usa una imagen JPEG, PNG o WebP de hasta 2 MiB.',
        );
      }
    } catch (_) {
      if (ref.mounted) {
        state = const ProfileAvatarState(
          errorMessage: 'No se pudo guardar el avatar. Revisa tu conexión y el correo verificado.',
        );
      }
    }
  }

  Future<void> eliminarAvatar(String uid) async {
    if (state.isBusy) return;
    state = const ProfileAvatarState(isBusy: true);
    try {
      await ref.read(profileAvatarRepositoryProvider).removeAvatar(uid);
      ref.invalidate(customerProfileProvider);
      ref.invalidate(avatarEligibilityProvider);
      if (ref.mounted) state = const ProfileAvatarState();
    } catch (_) {
      if (ref.mounted) {
        state = const ProfileAvatarState(
          errorMessage: 'No se pudo eliminar el avatar. Inténtalo de nuevo.',
        );
      }
    }
  }

  Future<void> seleccionarPreset(String uid, AvatarPreset preset) async {
    if (state.isBusy || !preset.available) return;
    state = const ProfileAvatarState(isBusy: true);
    try {
      await ref
          .read(profileAvatarRepositoryProvider)
          .saveAvatarPreset(uid, preset.value);
      if (ref.mounted) state = const ProfileAvatarState();
    } catch (_) {
      if (ref.mounted) {
        state = const ProfileAvatarState(
          errorMessage: 'No se pudo guardar la selección. Inténtalo de nuevo.',
        );
      }
    }
  }

  String _contentTypeFor(XFile image) {
    final mimeType = image.mimeType?.toLowerCase();
    if (mimeType != null &&
        MediaUploadValidator.supportedContentTypes.contains(mimeType)) {
      return mimeType;
    }

    final extension = image.name.split('.').last.toLowerCase();
    return switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => mimeType ?? 'application/octet-stream',
    };
  }
}

final profileControllerProvider =
    NotifierProvider<ProfileController, ProfileAvatarState>(
      ProfileController.new,
    );
