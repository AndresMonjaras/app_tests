import 'dart:typed_data';

abstract interface class ProfileAvatarRepository {
  Future<void> saveAvatar(String uid, Uint8List bytes, String contentType);

  Future<void> removeAvatar(String uid);
}
