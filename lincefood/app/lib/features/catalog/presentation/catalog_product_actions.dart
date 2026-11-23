import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../admin/presentation/admin_catalog_controller.dart';
import '../../admin/presentation/admin_catalog_providers.dart';
import '../../admin/presentation/admin_product_form.dart';
import '../domain/product.dart';

class CatalogProductActions {
  const CatalogProductActions(this.ref);

  final WidgetRef ref;

  BuildContext get context => ref.context;

  Future<void> edit([Product? product]) async {
    final updated = await showDialog<Product>(
      context: context,
      builder: (_) => AdminProductForm(product: product),
    );
    if (updated == null) return;
    await _perform(
      (controller) => controller.upsertProduct(updated),
      success: 'Producto guardado.',
      error: 'No se pudo guardar el producto.',
    );
  }

  Future<void> confirmDelete(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('¿Quieres retirar “${product.name}” del menú?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _perform(
      (controller) => controller.deleteProduct(product.id, confirmed: true),
      success: 'Se eliminó ${product.name} del menú.',
      error: 'No se pudo eliminar el producto.',
      action: SnackBarAction(
        label: 'Deshacer',
        onPressed: () => _perform(
          (controller) => controller.restoreProduct(product.id),
          success: 'Producto restaurado.',
          error: 'No se pudo restaurar el producto.',
        ),
      ),
    );
  }

  Future<void> _perform(
    Future<void> Function(AdminCatalogController) operation, {
    required String success,
    required String error,
    SnackBarAction? action,
  }) async {
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (ref.read(catalogEditorAccessProvider).asData?.value != true) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No tienes permiso para modificar el catálogo.'),
        ),
      );
      return;
    }
    var result = SnackBar(content: Text(success), action: action);
    try {
      await operation(ref.read(adminCatalogControllerProvider));
    } catch (_) {
      result = SnackBar(content: Text(error));
    }
    if (!context.mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(result);
  }
}
