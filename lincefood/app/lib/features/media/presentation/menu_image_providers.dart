import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/media_upload_validator.dart';
import 'media_storage_provider.dart';

/// Las fotos de menú dependen de Cloud Storage, que puede requerir plan de pago.
/// Se activan solo con `--dart-define=MENU_IMAGES_ENABLED=true`.
const menuImagesEnabledFromBuild = bool.fromEnvironment('MENU_IMAGES_ENABLED');

final menuImagesEnabledProvider = Provider<bool>(
  (ref) => menuImagesEnabledFromBuild,
);

String? menuImageAssetPath(String productId) {
  if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(productId)) return null;
  return 'assets/images/menu/$productId.jpg';
}

/// Caché en disco de fotos de menú. La clave es la ruta de Storage, no la URL
/// (que lleva un token cambiante), para encontrar la copia sin red.
final menuImageCacheManagerProvider = Provider<BaseCacheManager>(
  (ref) => CacheManager(
    Config(
      'menuImages',
      stalePeriod: const Duration(days: 60),
      maxNrOfCacheObjects: 200,
    ),
  ),
);

/// Archivo local de una foto de menú. Con copia vigente bajo [path] no usa red.
/// Si está vencida, intenta renovarla (URL de Storage + descarga con la misma
/// clave) y, si falla, conserva la copia vencida para seguir offline.
/// Null cuando no hay foto o está desactivada; sin red ni copia, falla.
final menuImageFileProvider = FutureProvider.autoDispose.family<File?, String>((
  ref,
  path,
) async {
  if (path.isEmpty || !ref.watch(menuImagesEnabledProvider)) return null;
  MediaUploadValidator.validateMenuImagePath(path);
  final cache = ref.watch(menuImageCacheManagerProvider);
  final storage = ref.watch(mediaStorageProvider);
  final cached = await cache.getFileFromCache(path);
  final fresh = cached != null && cached.validTill.isAfter(DateTime.now());
  if (fresh) return cached.file;

  try {
    final url = await storage.productImageUrl(path);
    final file = await cache.getSingleFile(url, key: path);
    return file;
  } catch (_) {
    if (cached != null && await cached.file.exists()) return cached.file;
    rethrow;
  }
});
