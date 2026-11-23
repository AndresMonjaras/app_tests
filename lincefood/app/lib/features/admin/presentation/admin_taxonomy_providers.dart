import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catalog/domain/product.dart';
import 'admin_catalog_providers.dart';
import 'admin_taxonomy_controller.dart';

typedef CatalogUnit = ({String label, String symbol});

const _defaults = {
  'g': (label: 'Gramos', symbol: 'g'),
  'ml': (label: 'Mililitros', symbol: 'ml'),
  'pz': (label: 'Piezas', symbol: 'pz'),
};

final adminUnitsProvider = StreamProvider.autoDispose<Map<String, CatalogUnit>>(
  (ref) {
    if (Firebase.apps.isEmpty) return Stream.value(_defaults);
    return FirebaseDatabase.instance.ref('units').onValue.map((event) {
      final units = <String, CatalogUnit>{};
      if (!event.snapshot.exists) return _defaults;
      for (final child in event.snapshot.children) {
        final code = child.key;
        final data = child.value;
        if (code != null &&
            isValidUnitCode(code) &&
            data is Map &&
            data['label'] is String &&
            data['symbol'] is String) {
          units[code] = (
            label: data['label'] as String,
            symbol: data['symbol'] as String,
          );
        }
      }
      return units;
    });
  },
);

final adminTaxonomyControllerProvider = Provider(
  (ref) => AdminTaxonomyController(
    ref.watch(callableAdminCatalogRepositoryProvider),
  ),
);
