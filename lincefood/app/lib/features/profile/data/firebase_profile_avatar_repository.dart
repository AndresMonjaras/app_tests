import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';

import '../../media/domain/media_storage.dart';
import '../../media/domain/media_upload_validator.dart';
import '../domain/avatar_rules.dart';
import '../domain/profile_avatar_repository.dart';

class FirebaseProfileAvatarRepository implements ProfileAvatarRepository {
  FirebaseProfileAvatarRepository({
    required this._authentication,
    required this._mediaStorage,
  });

  final FirebaseAuth _authentication;
  final MediaStorage _mediaStorage;

  @override
  Future<void> saveAvatar(
    String uid,
    Uint8List bytes,
    String contentType,
  ) async {
    final user = _requireEditableUser(uid);
    MediaUploadValidator.validate(bytes, contentType);

    final downloadUrl = await _mediaStorage.uploadAvatar(
      uid,
      bytes,
      contentType,
    );
    await user.updatePhotoURL(downloadUrl);
  }

  @override
  Future<void> removeAvatar(String uid) async {
    final user = _requireEditableUser(uid);
    await _mediaStorage.deleteAvatar(uid);
    await user.updatePhotoURL(null);
  }

  User _requireEditableUser(String uid) {
    final user = _authentication.currentUser;
    final providerId = user != null && user.providerData.length == 1
        ? user.providerData.single.providerId
        : '';
    if (user == null || user.uid != uid) {
      throw StateError('La sesión cambió. Inicia sesión e inténtalo de nuevo.');
    }
    if (!puedeEditarAvatar(providerId) || !user.emailVerified) {
      throw StateError(
        'Verifica el correo de tu cuenta para cambiar el avatar.',
      );
    }
    return user;
  }
}
