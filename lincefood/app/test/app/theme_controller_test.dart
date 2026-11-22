import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/app/theme_controller.dart';
import 'package:lincefood_app/app/theme_preference.dart';
import 'package:lincefood_app/app/theme_store.dart';

class _ThemeStorePendiente implements ThemeStore {
  final guardado = Completer<void>();

  @override
  Future<ThemePreference> leer() async => ThemePreference.sistema;

  @override
  Future<void> guardar(ThemePreference preferencia) => guardado.future;
}

void main() {
  test('carga el valor inicial y guarda cambios', () async {
    final store = ThemeStoreEnMemoria();
    final container = ProviderContainer(
      overrides: [themeStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    expect(
      await container.read(themeControllerProvider.future),
      ThemePreference.sistema,
    );

    await container
        .read(themeControllerProvider.notifier)
        .cambiar(ThemePreference.oscuro);

    expect(store.valorActual, ThemePreference.oscuro);
    expect(
      container.read(themeControllerProvider).value,
      ThemePreference.oscuro,
    );
  });

  test('conserva el último valor tras varios cambios', () async {
    final store = ThemeStoreEnMemoria();
    final container = ProviderContainer(
      overrides: [themeStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    await container.read(themeControllerProvider.future);
    final controller = container.read(themeControllerProvider.notifier);
    await controller.cambiar(ThemePreference.claro);
    await controller.cambiar(ThemePreference.oscuro);
    await controller.cambiar(ThemePreference.sistema);

    expect(store.valorActual, ThemePreference.sistema);
    expect(
      container.read(themeControllerProvider).value,
      ThemePreference.sistema,
    );
  });

  test(
    'no escribe estado si el provider se dispone durante el guardado',
    () async {
      final store = _ThemeStorePendiente();
      final container = ProviderContainer(
        overrides: [themeStoreProvider.overrideWithValue(store)],
      );
      await container.read(themeControllerProvider.future);
      final cambio = container
          .read(themeControllerProvider.notifier)
          .cambiar(ThemePreference.oscuro);

      container.dispose();
      store.guardado.complete();

      await expectLater(cambio, completes);
    },
  );
}
