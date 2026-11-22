import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../media/domain/media_storage.dart';
import '../../media/domain/media_upload_validator.dart';
import '../domain/avatar_rules.dart';
import '../domain/profile_avatar_repository.dart';

class FirebaseProfileAvatarRepository implements ProfileAvatarRepository {
  FirebaseProfileAvatarRepository({
    required this._authentication,
    required this._database,
    required this._mediaStorage,
  });

  final FirebaseAuth _authentication;
  final FirebaseDatabase _database;
  final MediaStorage _mediaStorage;

  @override
  Future<void> saveAvatar(
    String uid,
    Uint8List bytes,
    String contentType,
  ) async {
    final user = await _requireEditableUser(uid);
    MediaUploadValidator.validate(bytes, contentType);

    final profileReference = _database.ref('profiles/$uid');
    final previousPath =
        (await profileReference.child('avatarPath').get()).value;
    final uploadedAvatar = await _mediaStorage.uploadAvatar(
      uid,
      bytes,
      contentType,
    );
    final oldPhotoUrl = user.photoURL;
    try {
      await user.updatePhotoURL(uploadedAvatar.downloadUrl);
      await profileReference.update({
        'avatarPath': uploadedAvatar.path,
        'updatedAt': ServerValue.timestamp,
      });
    } catch (_) {
      try {
        await user.updatePhotoURL(oldPhotoUrl);
      } catch (_) {
        // La sesión podrá refrescar su photoURL al volver a iniciar.
      }
      try {
        await _mediaStorage.deleteAvatar(uid, uploadedAvatar.path);
      } catch (_) {
        // Limpieza best effort; conserva el error de actualización original.
      }
      rethrow;
    }
    if (previousPath is String && previousPath != uploadedAvatar.path) {
      try {
        await _mediaStorage.deleteAvatar(uid, previousPath);
      } catch (_) {
        // El avatar nuevo ya está guardado; la versión previa puede limpiarse después.
      }
    }
  }

  @override
  Future<void> removeAvatar(String uid) async {
    final user = await _requireEditableUser(uid);
    final profileReference = _database.ref('profiles/$uid');
    final previousPath =
        (await profileReference.child('avatarPath').get()).value;
    final oldPhotoUrl = user.photoURL;
    try {
      await user.updatePhotoURL(null);
      await profileReference.update({
        'avatarPath': null,
        'updatedAt': ServerValue.timestamp,
      });
    } catch (_) {
      try {
        await user.updatePhotoURL(oldPhotoUrl);
      } catch (_) {
        // La sesión podrá refrescar su photoURL al volver a iniciar.
      }
      rethrow;
    }
    if (previousPath is String) {
      try {
        await _mediaStorage.deleteAvatar(uid, previousPath);
      } catch (_) {
        // El perfil ya no referencia el objeto; la limpieza puede reintentarse.
      }
    }
  }

  Future<User> _requireEditableUser(String uid) async {
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
    final token = await user.getIdTokenResult(true);
    if (token.claims?['avatar_editable'] != true) {
      throw StateError(
        'Firebase aún no habilitó de forma segura el cambio de avatar.',
      );
    }
    return user;
  }
}
