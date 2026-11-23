import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/admin/data/admin_catalog_repository.dart';
import 'package:lincefood_app/features/admin/presentation/admin_catalog_controller.dart';
import 'package:lincefood_app/features/admin/presentation/admin_catalog_providers.dart';
import 'package:lincefood_app/features/catalog/domain/product.dart';
import 'package:lincefood_app/features/catalog/presentation/catalog_providers.dart';

class _Repository implements AdminCatalogRepository {
  bool deleted = false;
  bool? confirmed;
  bool restored = false;

  @override
  Future<void> deleteProduct(
    String productId, {
    required bool confirmed,
  }) async {
    deleted = true;
    this.confirmed = confirmed;
  }

  @override
  Future<void> restoreProduct(String productId) async {
    restored = true;
  }

  @override
  Future<List<Product>> fetchProducts() async => const [];

  @override
  Future<void> setProductAvailability(String productId, bool available) async {}

  @override
  Future<void> updateProductPrice(String productId, int priceCents) async {}

  @override
  Future<void> upsertProduct(Product product) async {}
}

void main() {
  test(
    'cada escritura refresca el menú y el listado de administración',
    () async {
      var menuReads = 0;
      var adminReads = 0;
      final container = ProviderContainer.test(
        overrides: [
          adminCatalogRepositoryProvider.overrideWithValue(_Repository()),
          catalogProductsProvider.overrideWith((ref) {
            menuReads++;
            return Stream.value(const <Product>[]);
          }),
          adminProductsProvider.overrideWith((ref) {
            adminReads++;
            return Stream.value(const <Product>[]);
          }),
        ],
      );
      container.listen(catalogProductsProvider, (_, _) {});
      container.listen(adminProductsProvider, (_, _) {});

      Future<void> checkReads(int expected) async {
        await container.pump();
        expect(menuReads, expected);
        expect(adminReads, expected);
      }

      final controller = container.read(adminCatalogControllerProvider);
      final product = Product(id: 'p1', name: 'Agua', priceCents: 1500);
      await checkReads(1);
      await controller.upsertProduct(product);
      await checkReads(2);
      await controller.deleteProduct(product.id, confirmed: true);
      await checkReads(3);
      await controller.restoreProduct(product.id);
      await checkReads(4);
    },
  );

  test('el controlador delega confirmación al repositorio', () async {
    final repository = _Repository();
    final controller = AdminCatalogController(repository);

    await controller.deleteProduct('p1', confirmed: false);
    expect(repository.deleted, isTrue);
    expect(repository.confirmed, isFalse);

    await controller.deleteProduct('p1', confirmed: true);
    expect(repository.deleted, isTrue);
    expect(repository.confirmed, isTrue);
  });
}
