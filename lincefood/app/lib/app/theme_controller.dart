import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme_preference.dart';
import 'theme_store.dart';

final themeStoreProvider = Provider<ThemeStore>((ref) {
  return ThemeStoreEnMemoria();
});

class ThemeController extends AsyncNotifier<ThemePreference> {
  @override
  Future<ThemePreference> build() {
    return ref.read(themeStoreProvider).leer();
  }

  Future<void> cambiar(ThemePreference preferencia) async {
    await ref.read(themeStoreProvider).guardar(preferencia);
    if (!ref.mounted) return;

    state = AsyncValue.data(preferencia);
  }
}

final themeControllerProvider =
    AsyncNotifierProvider<ThemeController, ThemePreference>(
      ThemeController.new,
    );
