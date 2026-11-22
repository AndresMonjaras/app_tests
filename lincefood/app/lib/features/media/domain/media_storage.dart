import 'dart:typed_data';

class StoredAvatar {
  const StoredAvatar({required this.path, required this.downloadUrl});

  final String path;
  final String downloadUrl;
}

abstract interface class MediaStorage {
  /// Sube la imagen y devuelve la ruta del objeto en Storage.
  Future<String> uploadProductImage(
    String productId,
    Uint8List bytes,
    String contentType,
  );

  /// Sube el avatar versionado y devuelve la ruta y URL de descarga.
  Future<StoredAvatar> uploadAvatar(
    String uid,
    Uint8List bytes,
    String contentType,
  );

  /// Elimina una versión concreta del avatar.
  Future<void> deleteAvatar(String uid, String path);

  /// Devuelve la URL de descarga de un objeto de menú (`menu/...`).
  Future<String> productImageUrl(String path);
}
