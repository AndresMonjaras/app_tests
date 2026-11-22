import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/admin/data/admin_roles_repository.dart';
import 'package:lincefood_app/features/admin/presentation/admin_catalog_busy_controller.dart';
import 'package:lincefood_app/features/admin/presentation/admin_product_variants_controller.dart';
import 'package:lincefood_app/features/admin/presentation/admin_roles_form_controller.dart';
import 'package:lincefood_app/features/catalog/domain/product.dart';
import 'package:lincefood_app/features/catalog/presentation/catalog_providers.dart';

class _RecordingRolesRepository implements AdminRolesRepository {
  final calls = <String>[];
  bool fails = false;

  @override
  Future<void> setRole(
    String uid, {
    required bool admin,
    required bool enabled,
  }) async {
    calls.add('$uid:$admin:$enabled');
    if (fails) throw StateError('sin conexión');
  }
}

ProviderContainer _container({List<Override> overrides = const <Override>[]}) {
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('AdminRolesFormController', () {
    test('cambia permiso y aplica el envío con el valor elegido', () async {
      final repo = _RecordingRolesRepository();
      final container = _container(
        overrides: [adminRolesRepositoryProvider.overrideWithValue(repo)],
      );
      final controller = container.read(adminRolesFormProvider.notifier);
      controller.setAdmin(true);
      controller.setEnabled(false);

      await controller.applyChange('uid-1');

      expect(repo.calls, ['uid-1:true:false']);
      final state = container.read(adminRolesFormProvider);
      expect(state.busy, isFalse);
      expect(state.result, contains('Permiso actualizado.'));
    });

    test('un fallo conserva el formulario y muestra error', () async {
      final repo = _RecordingRolesRepository()..fails = true;
      final container = _container(
        overrides: [adminRolesRepositoryProvider.overrideWithValue(repo)],
      );

      await container
          .read(adminRolesFormProvider.notifier)
          .applyChange('uid-2');

      final state = container.read(adminRolesFormProvider);
      expect(state.busy, isFalse);
      expect(state.result, startsWith('No se pudo cambiar el permiso.'));
      expect(state.admin, isFalse);
    });
  });

  group('AdminVariantsController', () {
    test('parte de las variantes del producto y permite agregar y quitar', () {
      final container = _container();
      final initial = <ProductVariant>[
        ProductVariant(label: "Grande", priceCents: 2550),
      ];
      final notifier = container.read(adminVariantsProvider(initial).notifier);

      final seeded = container.read(adminVariantsProvider(initial));
      expect(seeded.single.label.text, 'Grande');
      expect(seeded.single.price.text, '25.50');

      notifier.add();
      final afterAdd = container.read(adminVariantsProvider(initial));
      expect(afterAdd, hasLength(2));
      expect(afterAdd.last.label.text, isEmpty);

      notifier.remove(seeded.single);
      expect(container.read(adminVariantsProvider(initial)), hasLength(1));
    });
  });

  group('AdminCatalogBusyController', () {
    test('devuelve el resultado y libera el estado ocupado', () async {
      final container = _container();
      final notifier = container.read(adminCatalogBusyProvider.notifier);

      expect(await notifier.perform(() async {}), isTrue);
      expect(container.read(adminCatalogBusyProvider), isFalse);

      expect(
        await notifier.perform(() async => throw StateError('falla')),
        isFalse,
      );
      expect(container.read(adminCatalogBusyProvider), isFalse);
    });

    test('rechaza una segunda operación mientras hay una en curso', () async {
      final container = _container();
      final notifier = container.read(adminCatalogBusyProvider.notifier);
      final first = notifier.perform(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );

      expect(container.read(adminCatalogBusyProvider), isTrue);
      expect(await notifier.perform(() async {}), isFalse);
      expect(await first, isTrue);
    });
  });

  group('CatalogFilterController', () {
    test('guarda búsqueda y categoría por separado', () {
      final container = _container();
      final notifier = container.read(catalogFilterProvider.notifier);

      notifier.setQuery('cafe');
      notifier.selectCategory('Bebidas');
      var filter = container.read(catalogFilterProvider);
      expect(filter.query, 'cafe');
      expect(filter.category, 'Bebidas');

      notifier.selectCategory(null);
      filter = container.read(catalogFilterProvider);
      expect(filter.query, 'cafe');
      expect(filter.category, isNull);
    });
  });
}
