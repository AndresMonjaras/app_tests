import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/admin/data/admin_catalog_repository.dart';
import 'package:lincefood_app/features/admin/presentation/admin_catalog_controller.dart';
import 'package:lincefood_app/features/catalog/domain/product.dart';

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
  test('el controlador exige confirmación explícita antes de borrar', () async {
    final repository = _Repository();
    final controller = AdminCatalogController(repository);

    await expectLater(
      controller.deleteProduct('p1', confirmed: false),
      throwsA(isA<StateError>()),
    );
    expect(repository.deleted, isFalse);

    await controller.deleteProduct('p1', confirmed: true);
    expect(repository.deleted, isTrue);
    expect(repository.confirmed, isTrue);
  });
}
