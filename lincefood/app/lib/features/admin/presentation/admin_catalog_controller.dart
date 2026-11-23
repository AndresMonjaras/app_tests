import '../../catalog/domain/product.dart';
import '../data/admin_catalog_repository.dart';

class AdminCatalogController {
  const AdminCatalogController(this._repository, {this.onChanged});

  final AdminCatalogRepository _repository;

  final void Function()? onChanged;

  Future<void> upsertProduct(Product product) {
    return _refreshAfter(_repository.upsertProduct(product));
  }

  Future<void> deleteProduct(String productId, {required bool confirmed}) {
    return _refreshAfter(
      _repository.deleteProduct(productId, confirmed: confirmed),
    );
  }

  Future<void> restoreProduct(String productId) {
    return _refreshAfter(_repository.restoreProduct(productId));
  }

  Future<void> _refreshAfter(Future<void> write) async {
    await write;
    onChanged?.call();
  }
}
