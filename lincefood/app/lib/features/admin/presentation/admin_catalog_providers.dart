import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catalog/domain/product.dart';
import '../data/admin_catalog_repository.dart';

final adminAuthUserProvider = StreamProvider<User?>((ref) {
  if (Firebase.apps.isEmpty) return Stream<User?>.value(null);
  return FirebaseAuth.instance.authStateChanges();
});

Future<bool> _hasAdminClaim(Ref ref) async {
  final user = await ref.watch(adminAuthUserProvider.future);
  if (user == null) return false;

  try {
    final token = await user.getIdTokenResult(true);
    return token.claims?['admin'] == true;
  } catch (_) {
    return false;
  }
}

Future<bool> _hasCatalogEditorClaim(Ref ref) async {
  final user = await ref.watch(adminAuthUserProvider.future);
  if (user == null) return false;
  try {
    final token = await user.getIdTokenResult(true);
    final claims = token.claims;
    return claims?['admin'] == true || claims?['staff'] == true;
  } catch (_) {
    return false;
  }
}

final adminAccessProvider = FutureProvider<bool>(_hasAdminClaim);
final catalogEditorAccessProvider = FutureProvider<bool>(
  _hasCatalogEditorClaim,
);
final adminPanelAccessProvider = FutureProvider.autoDispose<bool>(
  _hasAdminClaim,
);

final adminCatalogRepositoryProvider = Provider<AdminCatalogRepository>((ref) {
  return CallableAdminCatalogRepository(
    FirebaseFunctions.instanceFor(region: 'us-central1'),
    FirebaseDatabase.instance,
  );
});

final adminProductsProvider = StreamProvider<List<Product>>((ref) {
  return FirebaseDatabase.instance.ref('products').onValue.map((event) {
    final data = event.snapshot.value;
    if (data is! Map) return const <Product>[];
    final products = <Product>[];
    data.forEach((key, value) {
      if (key is String && value is Map) {
        products.add(Product.fromMap(key, value));
      }
    });
    products.sort(
      (first, second) =>
          first.name.toLowerCase().compareTo(second.name.toLowerCase()),
    );
    return List.unmodifiable(products);
  });
});

final adminCategoriesProvider = StreamProvider<Map<String, String>>((ref) {
  if (Firebase.apps.isEmpty) return Stream.value(const <String, String>{});
  return FirebaseDatabase.instance.ref('categories').onValue.map((event) {
    final data = event.snapshot.value;
    if (data is! Map) return const <String, String>{};
    final categories = <String, String>{};
    data.forEach((key, value) {
      if (key is String && value is Map && value['name'] is String) {
        categories[key] = value['name'] as String;
      }
    });
    return Map.unmodifiable(categories);
  });
});
