import '../domain/catalog_repository.dart';
import '../domain/product.dart';

class InMemoryCatalogRepository implements CatalogRepository {
  InMemoryCatalogRepository(List<Product> products)
    : _products = List.unmodifiable(products);

  final List<Product> _products;

  @override
  Future<List<Product>> fetchProducts() async => List.unmodifiable(_products);
}
