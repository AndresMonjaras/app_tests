import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/media/domain/media_upload_validator.dart';

void main() {
  group('MediaUploadValidator', () {
    test('acepta JPEG, PNG y WebP de hasta 2 MiB', () {
      final bytes = Uint8List(MediaUploadValidator.maxFileSizeBytes);

      for (final contentType in MediaUploadValidator.supportedContentTypes) {
        expect(
          () => MediaUploadValidator.validate(bytes, contentType),
          returnsNormally,
        );
      }
    });

    test('rechaza SVG y otros tipos que no sean imágenes permitidas', () {
      final bytes = Uint8List(1);

      expect(
        () => MediaUploadValidator.validate(bytes, 'image/svg+xml'),
        throwsArgumentError,
      );
      expect(
        () => MediaUploadValidator.validate(bytes, 'application/pdf'),
        throwsArgumentError,
      );
    });

    test('rechaza archivos mayores a 2 MiB', () {
      final bytes = Uint8List(MediaUploadValidator.maxFileSizeBytes + 1);

      expect(
        () => MediaUploadValidator.validate(bytes, 'image/jpeg'),
        throwsArgumentError,
      );
    });
  });
}
