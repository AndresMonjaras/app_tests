import '../data/admin_catalog_repository.dart';

class AdminCatalogController {
  const AdminCatalogController(this._repository);

  final AdminCatalogRepository _repository;

  Future<void> deleteProduct(String productId, {required bool confirmed}) {
    return _repository.deleteProduct(productId, confirmed: confirmed);
  }

  Future<void> restoreProduct(String productId) {
    return _repository.restoreProduct(productId);
  }
}
