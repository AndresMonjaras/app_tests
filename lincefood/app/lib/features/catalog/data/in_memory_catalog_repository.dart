import 'dart:async';

import '../domain/catalog_repository.dart';
import '../domain/product.dart';

class InMemoryCatalogRepository implements CatalogRepository {
  InMemoryCatalogRepository(List<Product> products)
    : _products = List.of(products);

  final List<Product> _products;
  final StreamController<List<Product>> _controller =
      StreamController<List<Product>>.broadcast();

  @override
  Future<List<Product>> fetchProducts() async => List.unmodifiable(_products);

  @override
  Stream<List<Product>> watchProducts() {
    return Stream<List<Product>>.multi((controller) {
      controller.add(List.unmodifiable(_products));
      final subscription = _controller.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  void updateProducts(List<Product> products) {
    _products
      ..clear()
      ..addAll(products);
    _controller.add(List.unmodifiable(_products));
  }

  void dispose() {
    _controller.close();
  }
}
