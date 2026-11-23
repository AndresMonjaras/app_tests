import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../catalog/domain/product.dart';

abstract interface class AdminCatalogRepository {
  Future<List<Product>> fetchProducts();
  Future<void> upsertProduct(Product product);
  Future<void> updateProductPrice(String productId, int priceCents);
  Future<void> setProductAvailability(String productId, bool available);
  Future<void> deleteProduct(String productId, {required bool confirmed});
  Future<void> restoreProduct(String productId);
}

abstract interface class AdminTaxonomyRepository {
  Future<String> upsertCategory(String name, {String? id});
  Future<void> deleteCategory(String id);
  Future<void> upsertUnit(String code, String label, String symbol);
  Future<void> deleteUnit(String code);
}

class CallableAdminCatalogRepository
    implements AdminCatalogRepository, AdminTaxonomyRepository {
  CallableAdminCatalogRepository(this._functions, this._database);

  final FirebaseFunctions _functions;
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
  Future<void> upsertProduct(Product product) => _call('upsertProduct', {
    'productId': product.id,
    'product': {
      'name': product.name,
      'categoryId': product.categoryId,
      'priceCents': product.priceCents,
      'available': product.isAvailable,
      'imagePath': product.imagePath,
      'portionAmount': product.portionAmount,
      'portionUnit': product.portionUnit,
      'prepMinutes': product.prepMinutes,
      'description': product.description,
      'ingredients': product.ingredients,
      'complements': product.complements.map(_optionData).toList(),
      'variants': product.variants.map(_optionData).toList(),
    },
  });

  @override
  Future<void> updateProductPrice(String productId, int priceCents) => _call(
    'updateProductPrice',
    {'productId': productId, 'priceCents': priceCents},
  );

  @override
  Future<void> setProductAvailability(String productId, bool available) =>
      _call('setProductAvailability', {
        'productId': productId,
        'available': available,
      });

  @override
  Future<void> deleteProduct(String productId, {required bool confirmed}) =>
      _call('deleteProduct', {'productId': productId, 'confirmed': confirmed});

  @override
  Future<void> restoreProduct(String productId) =>
      _call('restoreProduct', {'productId': productId});

  @override
  Future<String> upsertCategory(String name, {String? id}) async {
    final result = await _functions.httpsCallable('upsertCategory').call({
      'id': ?id,
      'name': name,
    });
    return result.data['id'] as String;
  }

  @override
  Future<void> deleteCategory(String id) => _call('deleteCategory', {'id': id});

  @override
  Future<void> upsertUnit(String code, String label, String symbol) =>
      _call('upsertUnit', {'code': code, 'label': label, 'symbol': symbol});

  @override
  Future<void> deleteUnit(String code) => _call('deleteUnit', {'code': code});

  Map<String, Object> _optionData(ProductVariant option) => {
    'label': option.label,
    'priceCents': option.priceCents,
    'available': option.isAvailable,
  };

  Future<void> _call(String name, Map<String, Object?> data) async {
    await _functions.httpsCallable(name).call<Object?>(data);
  }
}
