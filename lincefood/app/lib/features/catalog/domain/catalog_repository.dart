import 'product.dart';

abstract interface class CatalogRepository {
  Future<List<Product>> fetchProducts();
}
