import 'dart:async';

import 'product.dart';

abstract interface class CatalogRepository {
  Future<List<Product>> fetchProducts();
  Stream<List<Product>> watchProducts();
}
