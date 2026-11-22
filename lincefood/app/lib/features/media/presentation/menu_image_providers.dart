import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'media_storage_provider.dart';

/// Las fotos de menú dependen de Cloud Storage, que puede requerir plan de pago.
/// Se activan solo con `--dart-define=MENU_IMAGES_ENABLED=true`.
const menuImagesEnabledFromBuild = bool.fromEnvironment('MENU_IMAGES_ENABLED');

final menuImagesEnabledProvider = Provider<bool>(
  (ref) => menuImagesEnabledFromBuild,
);

/// URL de descarga de una foto de menú. Null cuando no hay foto o está desactivada.
final menuImageUrlProvider = FutureProvider.autoDispose.family<String?, String>(
  (ref, path) async {
    if (path.isEmpty || !ref.watch(menuImagesEnabledProvider)) return null;
    return ref.watch(mediaStorageProvider).productImageUrl(path);
  },
);
