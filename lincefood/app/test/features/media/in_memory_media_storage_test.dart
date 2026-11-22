import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/media/data/in_memory_media_storage.dart';
import 'package:lincefood_app/features/media/domain/media_upload_validator.dart';

void main() {
  group('InMemoryMediaStorage', () {
    test('guarda imágenes de menú y avatar permitidos', () async {
      final storage = InMemoryMediaStorage();
      final bytes = Uint8List.fromList([1, 2, 3]);

      final productPath = await storage.uploadProductImage(
        'product-1',
        bytes,
        'image/webp',
      );
      final avatarPath = await storage.uploadAvatar(
        'user-1',
        bytes,
        'image/png',
      );

      expect(productPath, startsWith('menu/product-1/'));
      expect(avatarPath.path, startsWith('profiles/user-1/avatar/avatar-'));
      expect(avatarPath.downloadUrl, 'memory://${avatarPath.path}');
      expect(storage.files, hasLength(2));
      expect(
        storage.contentTypes.values,
        containsAll(['image/webp', 'image/png']),
      );
    });

    test('rechaza SVG y archivos mayores a 2 MiB', () async {
      final storage = InMemoryMediaStorage();
      final validBytes = Uint8List(1);
      final tooLargeBytes = Uint8List(
        MediaUploadValidator.maxFileSizeBytes + 1,
      );

      await expectLater(
        storage.uploadProductImage('product-1', validBytes, 'image/svg+xml'),
        throwsArgumentError,
      );
      await expectLater(
        storage.uploadAvatar('user-1', tooLargeBytes, 'image/jpeg'),
        throwsArgumentError,
      );
      expect(storage.files, isEmpty);
    });

    test('elimina el avatar sin afectar imágenes de menú', () async {
      final storage = InMemoryMediaStorage();
      final bytes = Uint8List.fromList([1, 2, 3]);
      final avatar = await storage.uploadAvatar('user-1', bytes, 'image/jpeg');
      await storage.uploadProductImage('product-1', bytes, 'image/jpeg');

      await storage.deleteAvatar('user-1', avatar.path);

      expect(
        storage.files.keys.any(
          (path) => path.startsWith('profiles/user-1/avatar/'),
        ),
        isFalse,
      );
      expect(storage.files.keys, hasLength(1));
    });
  });
}
