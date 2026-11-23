import '../data/admin_catalog_repository.dart';

class AdminTaxonomyController {
  const AdminTaxonomyController(this.repository);
  final AdminTaxonomyRepository repository;

  Future<String> saveCategory(String name, {String? id}) =>
      repository.upsertCategory(name.trim(), id: id);
  Future<void> removeCategory(String id) => repository.deleteCategory(id);
  Future<void> saveUnit(String code, String label, String symbol) =>
      repository.upsertUnit(code.trim(), label.trim(), symbol.trim());
  Future<void> removeUnit(String code) => repository.deleteUnit(code);
}
