import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../cart/presentation/cart_controller.dart';
import '../domain/product.dart';
import 'catalog_providers.dart';
import 'product_image.dart';

class CatalogScreen extends ConsumerWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(catalogProductsProvider);
    final filter = ref.watch(catalogFilterProvider);
    final query = filter.query;
    final category = filter.category;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lincefood'),
        actions: [
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
            return const Center(
              child: Text('No hay productos disponibles por ahora.'),
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
                          const SizedBox(height: 8),
                          LayoutBuilder(
                            builder: (context, constraints) => _CategoryGrid(
                              columns: _columnasCategorias(constraints.maxWidth),
                              children: [
                                for (final categoria in categories)
                                  _CategoryTile(
                                    label: categoria.isEmpty ? 'Otros' : categoria,
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
                                : selected.isEmpty
                                ? 'Otros'
                                : selected,
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
                      itemBuilder: (context, index) => _ProductTile(
                        product: filtered[index],
                        onAdd: (variant) {
                          ref
                              .read(cartControllerProvider.notifier)
                              .addProduct(
                                product: filtered[index],
                                variant: variant,
                              );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${filtered[index].name} se agregó al carrito.',
                              ),
                            ),
                          );
                        },
                      ),
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

IconData _categoryIcon(String category) {
  final name = category.toLowerCase();
  if (name.contains('beb') || name.contains('café') || name.contains('cafe')) {
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

    return Material(
      color: colors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textoFranja,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '$count productos',
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
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product, required this.onAdd});
  final Product product;
  final ValueChanged<ProductVariant?> onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showDetails(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ProductImage(
                imagePath: product.imagePath,
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
                    const SizedBox(height: 6),
                    Text(
                      '${product.variants.isEmpty ? '' : 'Desde '}${formatMoney(product.displayPriceCents)}${product.isAvailable ? '' : ' · Agotado'}',
                      style: TextStyle(
                        color: colors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: !product.isAvailable
                    ? 'Producto no disponible'
                    : product.variants.isEmpty
                    ? 'Agregar al carrito'
                    : 'Elegir variante',
                onPressed: product.isAvailable
                    ? () => _chooseVariant(context)
                    : null,
                icon: const Icon(Icons.add_shopping_cart),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDetails(BuildContext context) async {
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
                if (product.prepMinutes > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Preparación aproximada: ${product.prepMinutes} min',
                    ),
                  ),
                for (final v in product.variants)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(v.label),
                    trailing: Text(formatMoney(v.priceCents)),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: product.isAvailable
                        ? () => Navigator.pop(context, true)
                        : null,
                    child: Text(
                      product.isAvailable
                          ? 'Agregar al carrito'
                          : 'Producto no disponible',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (add == true && context.mounted) await _chooseVariant(context);
  }

  Future<void> _chooseVariant(BuildContext context) async {
    if (product.variants.isEmpty) {
      onAdd(null);
      return;
    }
    final selected = await showDialog<ProductVariant>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Elige una variante de ${product.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final variant in product.variants)
                ListTile(
                  title: Text(variant.label),
                  trailing: Text(formatMoney(variant.priceCents)),
                  onTap: () => Navigator.pop(context, variant),
                ),
            ],
          ),
        ),
      ),
    );
    if (context.mounted && selected != null) onAdd(selected);
  }
}
