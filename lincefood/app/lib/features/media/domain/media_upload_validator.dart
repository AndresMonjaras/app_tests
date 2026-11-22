import 'dart:typed_data';

class MediaUploadValidator {
  const MediaUploadValidator._();

  static const maxFileSizeBytes = 2 * 1024 * 1024;
  static const supportedContentTypes = {
    'image/jpeg',
    'image/png',
    'image/webp',
  };

  static void validate(Uint8List bytes, String contentType) {
    if (!supportedContentTypes.contains(contentType)) {
      throw ArgumentError.value(
        contentType,
        'contentType',
        'Solo se permiten imágenes JPEG, PNG o WebP.',
      );
    }

    if (bytes.length > maxFileSizeBytes) {
      throw ArgumentError.value(
        bytes.length,
        'bytes',
        'La imagen no puede exceder 2 MiB.',
      );
    }
  }

  static void validatePathSegment(String value, String name) {
    if (value.isEmpty || value.contains('/')) {
      throw ArgumentError.value(value, name, 'Debe ser un segmento válido.');
    }
  }

  /// Solo se permiten objetos del menú, nunca avatares ni rutas ajenas.
  static void validateMenuImagePath(String path) {
    final isMenuPath =
        path.startsWith('menu/') &&
        !path.contains('..') &&
        !path.contains('//');
    if (!isMenuPath) {
      throw ArgumentError.value(
        path,
        'path',
        'Ruta de imagen de menú no válida.',
      );
    }
  }
}
