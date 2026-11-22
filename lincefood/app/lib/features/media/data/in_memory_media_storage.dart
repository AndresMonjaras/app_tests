import 'dart:typed_data';

import '../domain/media_storage.dart';
import '../domain/media_upload_validator.dart';

class InMemoryMediaStorage implements MediaStorage {
  final Map<String, Uint8List> _files = {};
  final Map<String, String> _contentTypes = {};
  int _nextProductImageId = 0;
  int _nextAvatarVersion = 0;

  Map<String, Uint8List> get files => Map.unmodifiable({
    for (final entry in _files.entries)
      entry.key: Uint8List.fromList(entry.value),
  });

  Map<String, String> get contentTypes => Map.unmodifiable(_contentTypes);

  @override
  Future<String> uploadProductImage(
    String productId,
    Uint8List bytes,
    String contentType,
  ) async {
    MediaUploadValidator.validate(bytes, contentType);
    MediaUploadValidator.validatePathSegment(productId, 'productId');

    final path = 'menu/$productId/image-${_nextProductImageId++}';
    _save(path, bytes, contentType);
    return path;
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
        'profiles/$uid/avatar/avatar-${_nextAvatarVersion++}.$extension';
    _save(path, bytes, contentType);
    return StoredAvatar(path: path, downloadUrl: 'memory://$path');
  }

  @override
  Future<String> productImageUrl(String path) async {
    MediaUploadValidator.validateMenuImagePath(path);
    if (!_files.containsKey(path)) throw StateError('Objeto no encontrado.');
    return 'memory://$path';
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
    _files.remove(path);
    _contentTypes.remove(path);
  }

  void _save(String path, Uint8List bytes, String contentType) {
    _files[path] = Uint8List.fromList(bytes);
    _contentTypes[path] = contentType;
  }
}
