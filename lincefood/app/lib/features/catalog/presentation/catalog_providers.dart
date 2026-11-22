import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/realtime_database_catalog_repository.dart';
import '../domain/catalog_repository.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return RealtimeDatabaseCatalogRepository(FirebaseDatabase.instance);
});
