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
  Future<StoredAvatar> uploadAvatar(
    String uid,
    Uint8List bytes,
    String contentType,
  ) async {
    MediaUploadValidator.validate(bytes, contentType);
    MediaUploadValidator.validatePathSegment(uid, 'uid');

    final extension = switch (contentType) {
      'image/jpeg' => 'jpg',
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => throw ArgumentError.value(contentType, 'contentType'),
    };
    final path =
        'profiles/$uid/avatar/${DateTime.now().microsecondsSinceEpoch}.$extension';
    final reference = _storage.ref(path);
    await reference.putData(bytes, SettableMetadata(contentType: contentType));
    return StoredAvatar(
      path: path,
      downloadUrl: await reference.getDownloadURL(),
    );
  }

  @override
  Future<String> productImageUrl(String path) {
    MediaUploadValidator.validateMenuImagePath(path);
    return _storage.ref(path).getDownloadURL();
  }

  @override
  Future<void> deleteAvatar(String uid, String path) async {
    MediaUploadValidator.validatePathSegment(uid, 'uid');
    final prefix = 'profiles/$uid/avatar/';
    final fileName = path.startsWith(prefix)
        ? path.substring(prefix.length)
        : '';
    if (fileName.isEmpty || fileName.contains('/') || fileName.contains('..')) {
      throw ArgumentError.value(
        path,
        'path',
        'La ruta no pertenece al avatar.',
      );
    }
    try {
      await _storage.ref(path).delete();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') rethrow;
    }
  }
}
