import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../catalog/domain/product.dart';
import 'admin_catalog_controller.dart';
import 'admin_catalog_busy_controller.dart';
import 'admin_catalog_providers.dart';
import 'admin_product_form.dart';
import 'admin_roles_panel.dart';
import '../../catalog/presentation/catalog_providers.dart';

class AdminCatalogScreen extends ConsumerWidget {
  const AdminCatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(adminAccessProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Administración'),
          bottom: access.value == true
              ? const TabBar(
                  tabs: [
                    Tab(text: 'Productos y precios'),
                    Tab(text: 'Roles'),
                  ],
                )
              : null,
        ),
        body: access.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const _AccessDenied(),
          data: (allowed) => allowed
              ? TabBarView(
                  children: [
                    const _AdminCatalogContent(),
                    const AdminRolesPanel(),
                  ],
                )
              : const _AccessDenied(),
        ),
      ),
    );
  }
}

class _AccessDenied extends StatelessWidget {
  const _AccessDenied();

  @override
  Widget build(BuildContext context) => const Center(
    child: Text('No tienes permiso para administrar el catálogo.'),
  );
}

class _AdminCatalogContent extends ConsumerWidget {
  const _AdminCatalogContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(adminProductsProvider);
    final busy = ref.watch(adminCatalogBusyProvider);
    return AbsorbPointer(
      absorbing: busy,
      child: Column(
        children: [
          if (busy) const LinearProgressIndicator(),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                onPressed: () => _editProduct(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Agregar producto'),
              ),
            ),
          ),
          Expanded(
            child: products.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) =>
                  const Center(child: Text('No se pudo cargar el catálogo.')),
              data: (items) => items.isEmpty
                  ? const Center(child: Text('No hay productos.'))
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) => _ProductAdminTile(
                        product: items[index],
                        onPrice: () => _editProduct(
                          context,
                          ref,
                          product: items[index],
                          priceOnly: true,
                        ),
                        onEdit: () =>
                            _editProduct(context, ref, product: items[index]),
                        onAvailability: (available) => _setAvailability(
                          context,
                          ref,
                          items[index],
                          available,
                        ),
                        onArchive: () =>
                            _confirmArchive(context, ref, items[index]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editProduct(
    BuildContext context,
    WidgetRef ref, {
    Product? product,
    bool priceOnly = false,
  }) async {
    final updated = await showDialog<Product>(
      context: context,
      builder: (_) => AdminProductForm(
        product: product,
        priceOnly: priceOnly,
        onArchive: product == null
            ? null
            : () => _confirmArchive(context, ref, product),
      ),
    );
    if (updated == null || !context.mounted) return;
    await _perform(
      context,
      ref,
      () => ref.read(adminCatalogRepositoryProvider).upsertProduct(updated),
    );
  }

  Future<void> _setAvailability(
    BuildContext context,
    WidgetRef ref,
    Product product,
    bool available,
  ) async {
    await _perform(
      context,
      ref,
      () => ref
          .read(adminCatalogRepositoryProvider)
          .setProductAvailability(product.id, available),
    );
  }

  Future<void> _confirmArchive(
    BuildContext context,
    WidgetRef ref,
    Product product,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archivar producto'),
        content: Text(
          '¿Quieres archivar “${product.name}”? Se retirará del menú.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archivar producto'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final controller = AdminCatalogController(
      ref.read(adminCatalogRepositoryProvider),
    );
    await _perform(
      context,
      ref,
      () => controller.deleteProduct(product.id, confirmed: true),
    );
  }

  /// Ejecuta una escritura del catálogo, refresca los listados y muestra el resultado.
  Future<void> _perform(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() operation,
  ) async {
    if (ref.read(adminCatalogBusyProvider)) return;
    final ok = await ref
        .read(adminCatalogBusyProvider.notifier)
        .perform(operation);
    if (!context.mounted) return;
    if (ok) {
      ref.invalidate(adminProductsProvider);
      ref.invalidate(catalogProductsProvider);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Cambio guardado.' : 'No se pudo guardar el cambio.',
        ),
      ),
    );
  }
}

class _ProductAdminTile extends StatelessWidget {
  const _ProductAdminTile({
    required this.product,
    required this.onPrice,
    required this.onEdit,
    required this.onAvailability,
    required this.onArchive,
  });

  final Product product;
  final VoidCallback onPrice;
  final VoidCallback onEdit;
  final ValueChanged<bool> onAvailability;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      children: [
        ListTile(
          title: Text(product.name),
          leading: product.demo ? const Chip(label: Text('Demo')) : null,
          subtitle: Text(
            '${product.categoryId.isEmpty ? 'Sin categoría' : product.categoryId} · ${formatMoney(product.displayPriceCents)}',
          ),
          onTap: onEdit,
          trailing: IconButton(
            tooltip: 'Editar precio',
            onPressed: onPrice,
            icon: const Icon(Icons.edit_outlined),
          ),
        ),
        TextButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.tune),
          label: const Text('Editar producto'),
        ),
        SwitchListTile(
          title: Text(product.archived ? 'Archivado' : 'Disponible'),
          value: product.isAvailable && !product.archived,
          onChanged: product.archived ? null : onAvailability,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: product.archived ? null : onArchive,
            icon: const Icon(Icons.archive_outlined),
            label: const Text('Archivar'),
          ),
        ),
      ],
    ),
  );
}
