import '../data/admin_catalog_repository.dart';

class AdminCatalogController {
  const AdminCatalogController(this._repository);

  final AdminCatalogRepository _repository;

  Future<void> deleteProduct(String productId, {required bool confirmed}) {
    if (!confirmed) {
      return Future.error(StateError('Falta confirmar la eliminación.'));
    }
    return _repository.deleteProduct(productId, confirmed: true);
  }
}
