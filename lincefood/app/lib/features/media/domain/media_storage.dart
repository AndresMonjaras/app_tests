import 'dart:typed_data';

abstract interface class MediaStorage {
  /// Sube la imagen y devuelve la ruta del objeto en Storage.
  Future<String> uploadProductImage(
    String productId,
    Uint8List bytes,
    String contentType,
  );

  /// Sube el avatar y devuelve su URL de descarga.
  Future<String> uploadAvatar(String uid, Uint8List bytes, String contentType);

  Future<void> deleteAvatar(String uid);

  /// Devuelve la URL de descarga de un objeto de menú (`menu/...`).
  Future<String> productImageUrl(String path);
}
