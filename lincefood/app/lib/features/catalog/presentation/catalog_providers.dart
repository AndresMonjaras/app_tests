import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/in_memory_catalog_repository.dart';
import '../data/realtime_database_catalog_repository.dart';
import '../domain/catalog_repository.dart';
import '../domain/product.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  if (Firebase.apps.isEmpty) {
    final repository = InMemoryCatalogRepository(const []);
    ref.onDispose(repository.dispose);
    return repository;
  }
  return RealtimeDatabaseCatalogRepository(FirebaseDatabase.instance);
});

final catalogProductsProvider = StreamProvider<List<Product>>((ref) {
  return ref
      .watch(catalogRepositoryProvider)
      .watchProducts()
      .map(
        (products) => products
            .where((product) => !product.archived)
            .toList(growable: false),
      );
});

/// Filtros del menú: texto de búsqueda y categoría elegida (null = todas).
class CatalogFilter {
  const CatalogFilter({this.query = '', this.category});

  final String query;
  final String? category;
}

class CatalogFilterController extends Notifier<CatalogFilter> {
  @override
  CatalogFilter build() => const CatalogFilter();

  void setQuery(String query) {
    state = CatalogFilter(query: query, category: state.category);
  }

  void selectCategory(String? category) {
    state = CatalogFilter(query: state.query, category: category);
  }
}

final catalogFilterProvider =
    NotifierProvider.autoDispose<CatalogFilterController, CatalogFilter>(
      CatalogFilterController.new,
    );
