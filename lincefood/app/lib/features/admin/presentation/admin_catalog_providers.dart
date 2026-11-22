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

final adminAccessProvider = FutureProvider<bool>(_hasAdminClaim);
final adminPanelAccessProvider = FutureProvider.autoDispose<bool>(
  _hasAdminClaim,
);

final adminCatalogRepositoryProvider = Provider<AdminCatalogRepository>((ref) {
  return CallableAdminCatalogRepository(
    FirebaseFunctions.instanceFor(region: 'us-central1'),
    FirebaseDatabase.instance,
  );
});

final adminProductsProvider = FutureProvider<List<Product>>((ref) async {
  return ref.watch(adminCatalogRepositoryProvider).fetchProducts();
});
