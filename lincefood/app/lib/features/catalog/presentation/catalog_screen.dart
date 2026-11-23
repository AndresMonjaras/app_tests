import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_router.dart';
import '../../../core/money/money.dart';
import '../../admin/presentation/admin_catalog_providers.dart';
import '../../cart/presentation/cart_controller.dart';
import '../../profile/domain/avatar_preset.dart';
import '../domain/product.dart';
import 'catalog_product_actions.dart';
import 'catalog_providers.dart';
import 'product_image.dart';

class CatalogScreen extends ConsumerWidget {
  const CatalogScreen({
    super.key,
    this.userPhotoUrl,
    this.avatarPreset = AvatarPreset.neutro,
  });

  final String? userPhotoUrl;
  final AvatarPreset avatarPreset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(catalogProductsProvider);
    final actions = ref.watch(catalogEditorAccessProvider).asData?.value == true
        ? CatalogProductActions(ref)
        : null;
    final addButton = actions == null
        ? null
        : FilledButton.tonalIcon(
            onPressed: () => actions.edit(),
            icon: const Icon(Icons.add),
            label: const Text('Agregar producto'),
          );
    final filter = ref.watch(catalogFilterProvider);
    final query = filter.query;
    final category = filter.category;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lincefood'),
        actions: [
          IconButton(
            tooltip: 'Mi perfil',
            onPressed: () => Navigator.of(context).pushNamed(AppRouter.profile),
            icon: ProfileAvatar(
              preset: avatarPreset,
              photoUrl: userPhotoUrl,
              radius: 16,
            ),
          ),
          IconButton(
            tooltip: 'Abrir carrito',
            onPressed: () => Navigator.of(context).pushNamed('/cart'),
            icon: const Icon(Icons.shopping_cart_outlined),
          ),
        ],
      ),
      body: products.when(
        loading: () => const Center(
          child: CircularProgressIndicator(semanticsLabel: 'Cargando catálogo'),
        ),
        error: (_, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No se pudo cargar el catálogo. Inténtalo de nuevo.'),
              TextButton(
                onPressed: () => ref.invalidate(catalogProductsProvider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No hay productos disponibles por ahora.'),
                  ?addButton,
                ],
              ),
            );
          }
          final categories = items.map((p) => p.categoryId).toSet().toList()
            ..sort();
          final selected = categories.contains(category) ? category : null;
          final filtered = items
              .where(
                (p) =>
                    (selected == null || p.categoryId == selected) &&
                    p.name.toLowerCase().contains(query.toLowerCase()),
              )
              .toList();
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _anchoMaximoCatalogo),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: colors.tertiaryContainer,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TU PAUSA, CON SABOR',
                                  style: TextStyle(
                                    color: colors.onTertiaryContainer,
                                    letterSpacing: 2,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '¿Qué se te antoja hoy?',
                                  style: TextStyle(
                                    color: colors.onTertiaryContainer,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Elige tus favoritos y disfruta tu cafetería.',
                                  style: TextStyle(
                                    color: colors.onTertiaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            decoration: const InputDecoration(
                              hintText: 'Buscar en el menú',
                              prefixIcon: Icon(Icons.search),
                            ),
                            onChanged: (v) => ref
                                .read(catalogFilterProvider.notifier)
                                .setQuery(v),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Explora el menú',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ),
                              TextButton(
                                onPressed: () => ref
                                    .read(catalogFilterProvider.notifier)
                                    .selectCategory(null),
                                child: const Text('Ver todo'),
                              ),
                            ],
                          ),
                          ?addButton,
                          const SizedBox(height: 8),
                          LayoutBuilder(
                            builder: (context, constraints) => _CategoryGrid(
                              columns: _columnasCategorias(
                                constraints.maxWidth,
                              ),
                              children: [
                                for (final categoria in categories)
                                  _CategoryTile(
                                    label: _categoryLabel(categoria),
                                    count: items
                                        .where((p) => p.categoryId == categoria)
                                        .length,
                                    icon: _categoryIcon(categoria),
                                    selected: selected == categoria,
                                    onTap: () => ref
                                        .read(catalogFilterProvider.notifier)
                                        .selectCategory(categoria),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            selected == null
                                ? 'Para tu próxima pausa'
                                : _categoryLabel(selected),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (filtered.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No hay productos que coincidan con tu búsqueda.',
                        ),
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    sliver: SliverList.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final product = filtered[index];
                        final tile = _ProductTile(
                          product: product,
                          onEdit: actions == null
                              ? null
                              : () => actions.edit(product),
                          catalog: items,
                          onAdd: (product, variant, complements) {
                            ref
                                .read(cartControllerProvider.notifier)
                                .addProduct(
                                  product: product,
                                  variant: variant,
                                  complements: complements,
                                );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${product.name} se agregó al carrito.',
                                ),
                              ),
                            );
                          },
                        );
                        if (actions == null) return tile;
                        return Dismissible(
                          key: ValueKey(product.id),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (_) async {
                            await actions.confirmDelete(product);
                            // El stream retira la tarjeta al confirmarse la escritura.
                            return false;
                          },
                          background: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.only(right: 24),
                            alignment: Alignment.centerRight,
                            decoration: BoxDecoration(
                              color: colors.errorContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Quitar del menú',
                                  style: TextStyle(
                                    color: colors.onErrorContainer,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.delete_outline,
                                  color: colors.onErrorContainer,
                                ),
                              ],
                            ),
                          ),
                          child: tile,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// Evita que el contenido se estire en escritorio.
const _anchoMaximoCatalogo = 960.0;

// Los ids de Firebase se conservan; solo se traduce lo que ve el usuario.
String _categoryLabel(String category) {
  switch (category.trim().toLowerCase()) {
    case '':
      return 'Otros';
    case 'breakfast':
      return 'Desayunos';
    case 'tortas':
      return 'Tortas';
    case 'lunch':
      return 'Comidas';
    case 'drinks':
      return 'Bebidas';
    default:
      return category;
  }
}

IconData _categoryIcon(String category) {
  final name = category.toLowerCase();
  if (name.contains('drink') ||
      name.contains('beb') ||
      name.contains('café') ||
      name.contains('cafe')) {
    return Icons.local_cafe_outlined;
  }
  if (name.contains('post') || name.contains('dul')) return Icons.cake_outlined;
  if (name.contains('snack')) return Icons.bakery_dining_outlined;
  return Icons.restaurant_outlined;
}

// Dos columnas en teléfono, tres en tablet y cuatro en ventanas anchas.
int _columnasCategorias(double ancho) {
  if (ancho < 560) return 2;
  if (ancho < 900) return 3;
  return 4;
}

// Cuadrícula por filas con altura intrínseca: las tarjetas crecen con el
// texto si el usuario amplía la fuente, sin desbordarse.
class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.columns, required this.children});

  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final filas = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      final grupo = children.skip(i).take(columns).toList();
      final esUltimaFila = i + columns >= children.length;
      filas.add(
        Padding(
          padding: EdgeInsets.only(bottom: esUltimaFila ? 0 : 12),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var j = 0; j < columns; j++) ...[
                  if (j > 0) const SizedBox(width: 12),
                  Expanded(
                    child: j < grupo.length
                        ? grupo[j]
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }
    return Column(children: filas);
  }
}

// Tarjeta de categoría: icono sobre una franja de color con nombre y contador.
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.label,
    required this.count,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final franja = selected ? colors.tertiary : colors.primary;
    final textoFranja = selected ? colors.onTertiary : colors.onPrimary;

    return Semantics(
      selected: selected,
      child: Material(
        color: colors.surfaceContainerHigh,
        // El borde marca la selección además del color de la franja.
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: selected
              ? BorderSide(color: colors.onSurface, width: 2)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Icon(icon, size: 36, color: colors.primary),
              ),
              Container(
                width: double.infinity,
                color: franja,
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textoFranja,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      count == 1 ? '1 producto' : '$count productos',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textoFranja.withValues(alpha: 0.9),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.catalog,
    required this.onAdd,
    this.onEdit,
  });
  final Product product;
  final List<Product> catalog;
  final VoidCallback? onEdit;
  final void Function(Product, ProductVariant?, List<ProductVariant>) onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final content = InkWell(
      onTap: () => _showDetails(context, product),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ProductImage(
              imagePath: product.imagePath,
              productId: product.id,
              fallbackIcon: _categoryIcon(product.categoryId),
              width: 88,
              height: 88,
              borderRadius: 16,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  if (product.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      product.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    '${product.variants.isEmpty ? '' : 'Desde '}${formatMoney(product.displayPriceCents)}${product.canOrder ? '' : ' · Agotado'}',
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onEdit != null) const SizedBox(height: 40),
                IconButton.filled(
                  tooltip: !product.canOrder
                      ? 'Producto no disponible'
                      : product.variants.isEmpty
                      ? 'Agregar al carrito'
                      : 'Elegir variante',
                  onPressed: product.canOrder
                      ? () => _chooseVariant(context, product)
                      : null,
                  icon: const Icon(Icons.add_shopping_cart),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: onEdit == null
          ? content
          : Stack(
              children: [
                content,
                Positioned(
                  top: 8,
                  right: 12,
                  child: IconButton.filledTonal(
                    tooltip: 'Editar producto',
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: onEdit,
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _showDetails(BuildContext context, Product product) async {
    final related = catalog
        .where(
          (item) =>
              item.id != product.id && item.categoryId == product.categoryId,
        )
        .take(4)
        .toList();
    final add = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProductImage(
                  imagePath: product.imagePath,
                  productId: product.id,
                  fallbackIcon: _categoryIcon(product.categoryId),
                  width: double.infinity,
                  height: 200,
                  borderRadius: 24,
                ),
                const SizedBox(height: 24),
                Text(
                  product.name,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  '${product.variants.isEmpty ? '' : 'Desde '}${formatMoney(product.displayPriceCents)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(product.canOrder ? 'Disponible' : 'Agotado'),
                if (product.description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(product.description),
                ],
                if (product.ingredients.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Ingredientes',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(product.ingredients.join(', ')),
                ],
                if (product.prepMinutes > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Preparación aproximada: ${product.prepMinutes} min',
                    ),
                  ),
                if (product.variants.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Variantes',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  for (final option in product.variants)
                    _optionTile(option, available: product.isAvailable),
                ],
                if (product.complements.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Complementos opcionales',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  for (final option in product.complements)
                    _optionTile(option, available: product.isAvailable),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: product.canOrder
                        ? () => Navigator.pop(context, true)
                        : null,
                    child: Text(
                      product.canOrder
                          ? 'Agregar al carrito'
                          : 'Producto no disponible',
                    ),
                  ),
                ),
                if (related.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Productos relacionados',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  for (final item in related)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.name),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showDetails(context, item),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    if (add == true && context.mounted) await _chooseVariant(context, product);
  }

  Widget _optionTile(
    ProductVariant option, {
    bool available = true,
    VoidCallback? onTap,
    EdgeInsetsGeometry? contentPadding,
  }) {
    final enabled = available && option.isAvailable;
    return ListTile(
      contentPadding: contentPadding ?? EdgeInsets.zero,
      title: Text(option.label),
      subtitle: enabled ? null : const Text('Agotado'),
      trailing: Text(formatMoney(option.priceCents)),
      enabled: enabled,
      onTap: enabled ? onTap : null,
    );
  }

  Future<void> _chooseVariant(BuildContext context, Product product) async {
    if (!product.canOrder) return;
    ProductVariant? selected;
    if (product.variants.isNotEmpty) {
      selected = await showDialog<ProductVariant>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Elige una variante de ${product.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final variant in product.variants)
                  _optionTile(
                    variant,
                    onTap: () => Navigator.pop(context, variant),
                  ),
              ],
            ),
          ),
        ),
      );
      if (selected == null || !context.mounted) return;
    }

    var selectedComplements = <ProductVariant>[];
    if (product.complements.isNotEmpty) {
      final chosen = await showDialog<List<ProductVariant>>(
        context: context,
        builder: (dialogContext) {
          final choices = <String>{};
          return StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: Text('Complementos para ${product.name}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final option in product.complements)
                      CheckboxListTile(
                        value: choices.contains(option.label),
                        onChanged: option.isAvailable
                            ? (checked) => setDialogState(() {
                                if (checked == true) {
                                  choices.add(option.label);
                                } else {
                                  choices.remove(option.label);
                                }
                              })
                            : null,
                        title: Text(option.label),
                        subtitle: Text(
                          option.isAvailable
                              ? formatMoney(option.priceCents)
                              : 'Agotado',
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(
                    dialogContext,
                    product.complements
                        .where((item) => choices.contains(item.label))
                        .toList(),
                  ),
                  child: const Text('Continuar'),
                ),
              ],
            ),
          );
        },
      );
      if (chosen == null || !context.mounted) return;
      selectedComplements = chosen;
    }
    if (context.mounted) onAdd(product, selected, selectedComplements);
  }
}
