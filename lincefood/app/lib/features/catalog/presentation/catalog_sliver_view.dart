import 'package:flutter/material.dart';

import '../../../core/money/money.dart';
import '../domain/product.dart';

class CatalogSliverView extends StatelessWidget {
  const CatalogSliverView({
    super.key,
    required this.nombreCafeteria,
    required this.abierta,
    required this.categorias,
    required this.categoriaSeleccionada,
    required this.onCategoriaSeleccionada,
    required this.productos,
  });

  final String nombreCafeteria;
  final bool abierta;
  final List<String> categorias;
  final String categoriaSeleccionada;
  final ValueChanged<String> onCategoriaSeleccionada;
  final List<Product> productos;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnas = _columnasSegunAncho(constraints.maxWidth);
        return CustomScrollView(
          slivers: [
            _buildAppBar(context),
            SliverPersistentHeader(
              pinned: true,
              delegate: _CategoryHeaderDelegate(
                altura: 56,
                child: _buildCategorias(context),
              ),
            ),
            if (productos.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _EstadoVacio(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(12),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columnas,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.95,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        _ProductoCard(producto: productos[index]),
                    childCount: productos.length,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  int _columnasSegunAncho(double ancho) {
    if (ancho < 600) return 2;
    if (ancho < 900) return 3;
    if (ancho < 1200) return 4;
    return 5;
  }

  Widget _buildAppBar(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SliverAppBar(
      pinned: true,
      expandedHeight: 160,
      backgroundColor: colors.primary,
      foregroundColor: colors.onPrimary,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsetsDirectional.only(
          start: 16,
          bottom: 16,
          end: 16,
        ),
        title: Text(
          nombreCafeteria,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        background: Container(
          color: colors.primary,
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          alignment: Alignment.topLeft,
          child: SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topLeft,
              child: Chip(
                label: Text(abierta ? 'Abierto' : 'Cerrado'),
                backgroundColor: abierta
                    ? Colors.green.shade100
                    : Colors.red.shade100,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategorias(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      elevation: 2,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: categorias.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final categoria = categorias[index];
          return ChoiceChip(
            label: Text(categoria),
            selected: categoria == categoriaSeleccionada,
            onSelected: (seleccionada) {
              if (seleccionada) onCategoriaSeleccionada(categoria);
            },
          );
        },
      ),
    );
  }
}

class _CategoryHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _CategoryHeaderDelegate({required this.altura, required this.child});

  final double altura;
  final Widget child;

  @override
  double get minExtent => altura;

  @override
  double get maxExtent => altura;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(covariant _CategoryHeaderDelegate oldDelegate) {
    return oldDelegate.altura != altura || oldDelegate.child != child;
  }
}

class _ProductoCard extends StatelessWidget {
  const _ProductoCard({required this.producto});

  final Product producto;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Center(
                child: Icon(Icons.local_cafe, size: 40, color: colors.primary),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              producto.name,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(formatMoney(producto.displayPriceCents)),
          ],
        ),
      ),
    );
  }
}

class _EstadoVacio extends StatelessWidget {
  const _EstadoVacio();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('No hay productos disponibles por ahora.'),
      ),
    );
  }
}
