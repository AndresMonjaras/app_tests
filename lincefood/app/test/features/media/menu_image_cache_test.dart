import 'dart:io' as io;
import 'dart:typed_data';

import 'package:file/file.dart' as fs;
import 'package:file/local.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart' as cache;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/media/data/in_memory_media_storage.dart';
import 'package:lincefood_app/features/media/presentation/media_storage_provider.dart';
import 'package:lincefood_app/features/media/presentation/menu_image_providers.dart';

class _TempFileSystem implements cache.FileSystem {
  _TempFileSystem(this.root);

  final io.Directory root;

  @override
  Future<fs.File> createFile(String name) async {
    await root.create(recursive: true);
    return const LocalFileSystem().file('${root.path}/$name');
  }
}

class _OfflineMediaStorage extends InMemoryMediaStorage {
  @override
  Future<String> productImageUrl(String path) async =>
      throw const io.SocketException('Sin conexión');
}

void main() {
  test('usa la imagen guardada en disco si no se puede refrescar offline', () async {
    final tempDirectory = await io.Directory.systemTemp.createTemp(
      'lincefood-menu-cache-',
    );
    addTearDown(() => tempDirectory.delete(recursive: true));

    const cacheKey = 'offline-menu-image-test';
    const imagePath = 'menu/torta/v1.jpg';
    final databaseFile = io.File('${tempDirectory.path}/$cacheKey.json');
    final cacheFileSystem = _TempFileSystem(
      io.Directory('${tempDirectory.path}/files'),
    );

    cache.CacheManager createCacheManager() => cache.CacheManager(
      cache.Config(
        cacheKey,
        repo: cache.JsonCacheInfoRepository.withFile(databaseFile),
        fileSystem: cacheFileSystem,
      ),
    );

    final firstManager = createCacheManager();
    final savedBytes = Uint8List.fromList([1, 2, 3, 4]);
    final savedFile = await firstManager.putFile(
      'https://example.invalid/torta.jpg',
      savedBytes,
      key: imagePath,
      maxAge: Duration.zero,
      fileExtension: 'jpg',
    );
    await firstManager.dispose();

    // Crear otro manager con el mismo almacenamiento simula una nueva apertura.
    final reopenedManager = createCacheManager();
    addTearDown(reopenedManager.dispose);
    final container = ProviderContainer(
      overrides: [
        menuImagesEnabledProvider.overrideWithValue(true),
        menuImageCacheManagerProvider.overrideWithValue(reopenedManager),
        mediaStorageProvider.overrideWithValue(_OfflineMediaStorage()),
      ],
    );
    addTearDown(container.dispose);

    final image = await container.read(menuImageFileProvider(imagePath).future);

    expect(image, isNotNull);
    expect(image!.path, savedFile.path);
    expect(await image.readAsBytes(), savedBytes);
  });
}
