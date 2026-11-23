import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/admin/data/admin_catalog_repository.dart';
import 'package:lincefood_app/features/admin/presentation/admin_taxonomy_controller.dart';
import 'package:lincefood_app/features/catalog/domain/product.dart';

class _Repository implements AdminTaxonomyRepository {
  final categories = <String, String>{};
  final units = <String, (String, String)>{};
  String? inUse;

  @override
  Future<String> upsertCategory(String name, {String? id}) async {
    final key = id ?? 'nueva';
    categories[key] = name;
    return key;
  }

  @override
  Future<void> upsertUnit(String code, String label, String symbol) async {
    units[code] = (label, symbol);
  }

  void checkUsage(String key) {
    if (inUse == key) {
      throw FirebaseFunctionsException(
        code: 'failed-precondition',
        message: 'Un producto usa este elemento.',
      );
    }
  }

  @override
  Future<void> deleteCategory(String id) async {
    checkUsage(id);
    categories.remove(id);
  }

  @override
  Future<void> deleteUnit(String code) async {
    checkUsage(code);
    units.remove(code);
  }
}

void main() {
  test('crea, edita y elimina categorías y unidades', () async {
    final repo = _Repository();
    final controller = AdminTaxonomyController(repo);
    final id = await controller.saveCategory(' Pan ');
    await controller.saveUnit('kg', 'Kilogramos', 'kg');
    expect(repo.categories, {id: 'Pan'});
    expect(repo.units, {'kg': ('Kilogramos', 'kg')});
    await controller.saveCategory('Pan dulce', id: id);
    await controller.saveUnit('kg', 'Kilos', 'kg');
    expect(repo.categories, {id: 'Pan dulce'});
    expect(repo.units, {'kg': ('Kilos', 'kg')});
    await controller.removeCategory(id);
    await controller.removeUnit('kg');
    expect(repo.categories, isEmpty);
    expect(repo.units, isEmpty);
  });

  test('conserva el error de uso de la callable', () async {
    final repo = _Repository()..inUse = 'ocupado';
    final controller = AdminTaxonomyController(repo);
    final error = throwsA(
      isA<FirebaseFunctionsException>()
          .having((e) => e.code, 'código', 'failed-precondition')
          .having(
            (e) => e.message,
            'mensaje',
            'Un producto usa este elemento.',
          ),
    );
    await expectLater(controller.removeCategory('ocupado'), error);
    await expectLater(controller.removeUnit('ocupado'), error);
  });

  test('acepta códigos personalizados y descarta los inválidos', () {
    for (final code in ['kg', 'caja_12', 'abcdefghij', '0']) {
      expect(Product.fromMap('p', {'portionUnit': code}).portionUnit, code);
    }
    for (final code in ['', 'KG', 'a-b', 'abcdefghijk', 1]) {
      expect(Product.fromMap('p', {'portionUnit': code}).portionUnit, isNull);
    }
  });
}
