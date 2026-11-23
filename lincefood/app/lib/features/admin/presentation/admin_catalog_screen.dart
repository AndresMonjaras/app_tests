import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../shared/responsive/breakpoints.dart';
import '../../catalog/domain/product.dart';
import '../../catalog/presentation/product_image.dart';
import 'admin_catalog_controller.dart';
import 'admin_catalog_busy_controller.dart';
import 'admin_catalog_providers.dart';
import 'admin_content_layout.dart';
import 'admin_product_form.dart';
import 'admin_roles_panel.dart';
import '../../catalog/presentation/catalog_providers.dart';

class AdminCatalogScreen extends ConsumerWidget {
  const AdminCatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(catalogEditorAccessProvider);
    final isAdmin = ref.watch(adminAccessProvider).value == true;
    final showRoles = access.value == true && isAdmin;
    return DefaultTabController(
      length: showRoles ? 2 : 1,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isAdmin ? 'Administración' : 'Productos de cafetería'),
          bottom: showRoles
              ? const TabBar(
                  tabs: [
                    Tab(text: 'Productos y precios'),
                    Tab(text: 'Roles'),
                  ],
                )
              : null,
        ),
        body: AdminContentLayout(
          child: access.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const _AccessDenied(),
            data: (allowed) {
              if (!allowed) return const _AccessDenied();
              if (!isAdmin) return const _AdminCatalogContent();
              return const TabBarView(
                children: [_AdminCatalogContent(), AdminRolesPanel()],
              );
            },
          ),
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
              error: (_, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('No se pudo cargar el catálogo.'),
                    OutlinedButton(
                      onPressed: () => ref.invalidate(adminProductsProvider),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const Center(child: Text('No hay productos.'));
                }
                Widget productTile(int index) => _ProductAdminTile(
                  product: items[index],
                  onPrice: () => _editProduct(
                    context,
                    ref,
                    product: items[index],
                    priceOnly: true,
                  ),
                  onEdit: () =>
                      _editProduct(context, ref, product: items[index]),
                  onAvailability: (available) =>
                      _setAvailability(context, ref, items[index], available),
                  onArchive: () => _confirmArchive(context, ref, items[index]),
                  onRestore: () => _restoreProduct(context, ref, items[index]),
                );
                final desktop = context.isDesktop;
                return ListView.builder(
                  itemCount: desktop ? (items.length + 1) ~/ 2 : items.length,
                  itemBuilder: (context, row) {
                    if (!desktop) return productTile(row);
                    final first = row * 2;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: productTile(first)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: first + 1 < items.length
                              ? productTile(first + 1)
                              : const SizedBox.shrink(),
                        ),
                      ],
                    );
                  },
                );
              },
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

  Future<void> _restoreProduct(
    BuildContext context,
    WidgetRef ref,
    Product product,
  ) async {
    final controller = AdminCatalogController(
      ref.read(adminCatalogRepositoryProvider),
    );
    await _perform(context, ref, () => controller.restoreProduct(product.id));
  }

  /// Ejecuta una escritura del catálogo, refresca los listados y muestra el resultado.
  Future<void> _perform(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() operation,
  ) async {
    if (ref.read(adminCatalogBusyProvider)) return;
    final errorMessage = await ref
        .read(adminCatalogBusyProvider.notifier)
        .perform(operation);
    if (!context.mounted) return;
    if (errorMessage == null) {
      ref.invalidate(adminProductsProvider);
      ref.invalidate(catalogProductsProvider);
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(errorMessage ?? 'Cambio guardado.')));
  }
}

class _ProductAdminTile extends StatelessWidget {
  const _ProductAdminTile({
    required this.product,
    required this.onPrice,
    required this.onEdit,
    required this.onAvailability,
    required this.onArchive,
    required this.onRestore,
  });

  final Product product;
  final VoidCallback onPrice;
  final VoidCallback onEdit;
  final ValueChanged<bool> onAvailability;
  final VoidCallback onArchive;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final category = product.categoryId.isEmpty
        ? 'Sin categoría'
        : product.categoryId;
    final portion = product.portionAmount == null
        ? ''
        : ' · ${product.portionAmount} ${product.portionUnit}';
    final status = product.archived
        ? 'Archivado'
        : product.isAvailable
        ? 'Disponible'
        : 'Agotado';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onEdit,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  product.demo
                      ? const Chip(label: Text('Demo'))
                      : ProductImage(
                          imagePath: product.imagePath,
                          productId: product.id,
                          fallbackIcon: Icons.restaurant_outlined,
                          width: 56,
                          height: 56,
                          borderRadius: 12,
                        ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '$category$portion',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${formatMoney(product.displayPriceCents)} · $status',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: product.archived || !product.isAvailable
                                ? scheme.onSurfaceVariant
                                : scheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Editar precio',
                    onPressed: onPrice,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.tune),
                  label: const Text('Editar producto'),
                ),
                OutlinedButton.icon(
                  onPressed: product.archived ? onRestore : onArchive,
                  icon: Icon(
                    product.archived
                        ? Icons.unarchive_outlined
                        : Icons.archive_outlined,
                  ),
                  label: Text(product.archived ? 'Restaurar' : 'Archivar'),
                ),
              ],
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(product.archived ? 'Archivado' : 'Disponible'),
              value: product.isAvailable && !product.archived,
              onChanged: product.archived ? null : onAvailability,
            ),
          ],
        ),
      ),
    );
  }
}
