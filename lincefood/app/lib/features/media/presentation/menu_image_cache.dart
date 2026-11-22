import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Política persistente para imágenes públicas del menú.
const menuImageCacheStaleDays = int.fromEnvironment(
  'MENU_IMAGE_CACHE_STALE_DAYS',
  defaultValue: 7,
);
const menuImageCacheMaxObjects = int.fromEnvironment(
  'MENU_IMAGE_CACHE_MAX_OBJECTS',
  defaultValue: 200,
);

final menuImageCacheManager = CacheManager(
  Config(
    'lincefood-menu-images',
    stalePeriod: Duration(days: menuImageCacheStaleDays),
    maxNrOfCacheObjects: menuImageCacheMaxObjects,
  ),
);
