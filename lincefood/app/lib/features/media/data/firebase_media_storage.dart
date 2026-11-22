import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import '../domain/media_storage.dart';
import '../domain/media_upload_validator.dart';

class FirebaseMediaStorage implements MediaStorage {
  FirebaseMediaStorage([FirebaseStorage? storage])
    : _storage = storage ?? FirebaseStorage.instance;

  static int _nextProductImageId = 0;

  final FirebaseStorage _storage;

  @override
  Future<String> uploadProductImage(
    String productId,
    Uint8List bytes,
    String contentType,
  ) async {
    MediaUploadValidator.validate(bytes, contentType);
    MediaUploadValidator.validatePathSegment(productId, 'productId');

    final fileName =
        'image-${DateTime.now().microsecondsSinceEpoch}-${_nextProductImageId++}';
    final reference = _storage.ref('menu/$productId/$fileName');
    await reference.putData(bytes, SettableMetadata(contentType: contentType));
    return reference.fullPath;
  }

  @override
  Future<String> uploadAvatar(
    String uid,
    Uint8List bytes,
    String contentType,
  ) async {
    MediaUploadValidator.validate(bytes, contentType);
    MediaUploadValidator.validatePathSegment(uid, 'uid');

    final reference = _storage.ref('profiles/$uid/avatar/avatar');
    await reference.putData(bytes, SettableMetadata(contentType: contentType));
    return reference.getDownloadURL();
  }

  @override
  Future<String> productImageUrl(String path) {
    MediaUploadValidator.validateMenuImagePath(path);
    return _storage.ref(path).getDownloadURL();
  }

  @override
  Future<void> deleteAvatar(String uid) async {
    MediaUploadValidator.validatePathSegment(uid, 'uid');
    try {
      await _storage.ref('profiles/$uid/avatar/avatar').delete();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') rethrow;
    }
  }
}
