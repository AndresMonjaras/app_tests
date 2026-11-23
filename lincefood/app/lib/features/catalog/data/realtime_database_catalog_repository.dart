import 'package:firebase_database/firebase_database.dart';

import '../domain/catalog_repository.dart';
import '../domain/product.dart';

class RealtimeDatabaseCatalogRepository implements CatalogRepository {
  const RealtimeDatabaseCatalogRepository(this._database);

  final FirebaseDatabase _database;

  @override
  Future<List<Product>> fetchProducts() async {
    final snapshot = await _database.ref('products').get();
    final data = snapshot.value;
    if (data is! Map) return const [];

    final products = <Product>[];
    data.forEach((key, value) {
      if (key is String && value is Map) {
        products.add(Product.fromMap(key, value));
      }
    });

    return List.unmodifiable(products);
  }

  @override
  Stream<List<Product>> watchProducts() =>
      _database.ref('products').onValue.map((event) {
        final data = event.snapshot.value;
        if (data is! Map) return const <Product>[];
        final products = <Product>[];
        data.forEach((key, value) {
          if (key is String && value is Map) {
            products.add(Product.fromMap(key, value));
          }
        });
        return List.unmodifiable(products);
      });
}
