import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_router.dart';
import '../../../core/money/money.dart';
import '../../../shared/responsive/breakpoints.dart';
import '../../../shared/widgets/fixed_bottom_bar.dart';
import '../../catalog/domain/product.dart';
import '../../catalog/presentation/catalog_providers.dart';
import '../../catalog/presentation/product_image.dart';
import '../../orders/domain/pickup_mode.dart';
import '../../orders/presentation/order_actions_controller.dart';
import '../../orders/presentation/orders_providers.dart';
import '../../payments/presentation/payment_providers.dart';
import '../domain/cart.dart';
import 'cart_controller.dart';
import 'cart_checkout_controller.dart';

const _singleColumnMaxWidth = 720.0;

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider);
    final pickupMode = ref.watch(pickupModeProvider);
    final checkout = ref.watch(cartCheckoutProvider);
    final configured = ref.watch(paymentConfiguredProvider);
    final uid = ref.watch(uidActivoProvider);
    final catalog = ref.watch(catalogProductsProvider);
    final firebaseConfigured = Firebase.apps.isNotEmpty;
    final catalogReady =
        !firebaseConfigured ||
        (catalog.hasValue && !catalog.hasError && !catalog.isLoading);
    final matches = ref
        .read(cartCheckoutProvider.notifier)
        .matches(cart, uid, pickupMode);
    final serverOrder = matches ? checkout.order : null;
    final lines = serverOrder?.lines ?? cart.lines;
    final latestProducts = {
      for (final product in catalog.value ?? const <Product>[])
        product.id: product,
    };
    final catalogIssues = <String, String>{};
    if (firebaseConfigured && catalogReady) {
      for (final line in lines) {
        final issue = _catalogIssue(line, latestProducts);
        if (issue != null) catalogIssues[_cartLineKey(line)] = issue;
      }
    }
    final total = formatMoney(serverOrder?.totalCents ?? cart.totalCents);
    final subtotal = lines.fold<int>(0, (sum, line) => sum + line.totalCents);
    final error = checkout.message;
    final busy = checkout.isWorking;

    final desktop = context.isDesktop;
    final products = <Widget>[
      _CartHeader(items: lines.fold<int>(0, (sum, l) => sum + l.quantity)),
      const SizedBox(height: 12),
      if (!catalogReady) ...[
        Text(
          catalog.hasError
              ? 'No se pudo verificar el menú. Reintenta antes de pagar.'
              : 'Verificando disponibilidad y precios del menú…',
          style: TextStyle(
            color: catalog.hasError
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (catalog.hasError)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => ref.invalidate(catalogProductsProvider),
              child: const Text('Reintentar'),
            ),
          ),
      ],
      for (final line in lines)
        _CartLineTile(
          line: line,
          catalogIssue: catalogIssues[_cartLineKey(line)],
          onDecrease: busy
              ? null
              : () => ref
                    .read(cartControllerProvider.notifier)
                    .changeQuantity(
                      productId: line.product.id,
                      variantLabel: line.variant?.label,
                      complementLabels: line.complements
                          .map((item) => item.label)
                          .toList(),
                      quantity: line.quantity - 1,
                    ),
          onIncrease: busy
              ? null
              : () => ref
                    .read(cartControllerProvider.notifier)
                    .changeQuantity(
                      productId: line.product.id,
                      variantLabel: line.variant?.label,
                      complementLabels: line.complements
                          .map((item) => item.label)
                          .toList(),
                      quantity: line.quantity + 1,
                    ),
          onRemove: busy
              ? null
              : () => ref
                    .read(cartControllerProvider.notifier)
                    .removeLine(
                      productId: line.product.id,
                      variantLabel: line.variant?.label,
                      complementLabels: line.complements
                          .map((item) => item.label)
                          .toList(),
                    ),
        ),
      if (catalogIssues.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(
          'El menú cambió. Quita los productos marcados y agrégalos de nuevo para confirmar los datos actuales.',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
    ];
    final pickup = <Widget>[
      Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.storefront_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Modalidad de recogida',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<PickupMode>(
                  showSelectedIcon: false,
                  segments: [
                    for (final mode in PickupMode.values)
                      ButtonSegment<PickupMode>(
                        value: mode,
                        label: Text(
                          mode.label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                        ),
                      ),
                  ],
                  selected: {pickupMode},
                  onSelectionChanged: busy
                      ? null
                      : (selection) => ref
                            .read(pickupModeProvider.notifier)
                            .select(selection.first),
                ),
              ),
            ],
          ),
        ),
      ),
      if (uid == null || uid.isEmpty) ...[
        const SizedBox(height: 12),
        const Text('Inicia sesión para pagar tu pedido.'),
      ],
      if (!configured) const Text('Pagos no configurados'),
      if (error != null) ...[
        const SizedBox(height: 12),
        Text(
          error,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
    ];
    final summary = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [const Text('Subtotal'), Text(formatMoney(subtotal))],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Total', style: Theme.of(context).textTheme.titleMedium),
            Text(
              total,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              textStyle: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            onPressed:
                uid == null ||
                    uid.isEmpty ||
                    !configured ||
                    !catalogReady ||
                    catalogIssues.isNotEmpty ||
                    busy
                ? null
                : () => _submit(context, ref, cart, uid, pickupMode),
            child: busy
                ? SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.onPrimary,
                      semanticsLabel: 'Procesando pago',
                    ),
                  )
                : Text('Pagar $total'),
          ),
        ),
      ],
    );
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Carrito')),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: desktop
                  ? desktopContentMaxWidth
                  : _singleColumnMaxWidth,
            ),
            child: desktop && cart.isEmpty
                ? const Center(
                    child: SingleChildScrollView(child: _EmptyCart()),
                  )
                : desktop
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: ListView(children: products)),
                        const SizedBox(width: 24),
                        SizedBox(
                          width: 380,
                          child: ListView(
                            primary: false,
                            children: [
                              ...pickup,
                              const SizedBox(height: 12),
                              Card(
                                margin: EdgeInsets.zero,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: summary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: cart.isEmpty
                        ? const [_EmptyCart()]
                        : [...products, const SizedBox(height: 4), ...pickup],
                  ),
          ),
        ),
        bottomNavigationBar: desktop || cart.isEmpty
            ? null
            : FixedBottomBar(
                child: Center(
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _singleColumnMaxWidth,
                    ),
                    child: summary,
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _submit(
    BuildContext context,
    WidgetRef ref,
    Cart cart,
    String uid,
    PickupMode pickupMode,
  ) async {
    if (!identical(ref.read(cartControllerProvider), cart)) return;
    final order = await ref
        .read(cartCheckoutProvider.notifier)
        .pay(cart: cart, uid: uid, pickupMode: pickupMode);
    if (order == null || !context.mounted) return;

    final cartController = ref.read(cartControllerProvider.notifier);
    if (identical(ref.read(cartControllerProvider), cart)) {
      cartController.clear();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pago enviado. El pedido se está verificando.'),
      ),
    );
    Navigator.of(
      context,
    ).pushReplacementNamed(AppRouter.orders, arguments: {'orderId': order.id});
  }
}

/// Encabezado con el conteo de articulos del pedido.
class _CartHeader extends StatelessWidget {
  const _CartHeader({required this.items});

  final int items;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.shopping_bag_outlined, color: colors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Tu pedido',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            items == 1 ? '1 artículo' : '$items artículos',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colors.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          ExcludeSemantics(
            child: Image.asset(
              'assets/images/mojarra/mojarra_sola.png',
              height: 120,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.shopping_bag_outlined, size: 72),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Tu carrito está vacío.',
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Agrega algo del menú para empezar tu pedido.',
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _CartLineTile extends StatelessWidget {
  const _CartLineTile({
    required this.line,
    required this.onDecrease,
    required this.onIncrease,
    required this.onRemove,
    this.catalogIssue,
  });

  final CartLine line;
  final String? catalogIssue;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final variant = line.variant == null ? '' : ' (${line.variant!.label})';
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final nombre = '${line.product.name}$variant';
    final complementLabels = line.complements
        .map((item) => item.label)
        .toList();
    final hasIssue = catalogIssue != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: hasIssue ? colors.error : colors.outlineVariant,
          width: hasIssue ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProductImage(
                  imagePath: line.product.imagePath,
                  productId: line.product.id,
                  fallbackIcon: Icons.restaurant,
                  width: 76,
                  height: 76,
                  borderRadius: 16,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (complementLabels.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Complementos: ${complementLabels.join(', ')}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        '${formatMoney(line.unitPriceCents)} c/u',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Quitar $nombre',
                  onPressed: onRemove,
                  color: colors.error,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Reducir cantidad de $nombre',
                        onPressed: onDecrease,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      SizedBox(
                        width: 28,
                        child: Semantics(
                          label: 'Cantidad: ${line.quantity}',
                          excludeSemantics: true,
                          child: Text(
                            '${line.quantity}',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Aumentar cantidad de $nombre',
                        onPressed: onIncrease,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Subtotal ${formatMoney(line.totalCents)}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            if (hasIssue)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  catalogIssue!,
                  style: TextStyle(color: colors.onErrorContainer),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _cartLineKey(CartLine line) =>
    '${line.product.id}::${line.variant?.label ?? ''}::${(line.complements.map((item) => item.label).toList()..sort()).join('|')}';

String? _catalogIssue(CartLine line, Map<String, Product> currentProducts) {
  final current = currentProducts[line.product.id];
  if (current == null) {
    return 'Ya no aparece en el menú. Quítalo antes de pagar.';
  }
  if (!current.isAvailable) {
    return 'Está agotado. Quítalo antes de pagar.';
  }
  if (current.name != line.product.name) {
    return 'Ahora aparece como “${current.name}”. Quítalo y agrégalo de nuevo.';
  }

  for (final selected in line.complements) {
    ProductVariant? currentComplement;
    for (final option in current.complements) {
      if (option.label == selected.label) currentComplement = option;
    }
    if (currentComplement == null || !currentComplement.isAvailable) {
      return 'El complemento ${selected.label} ya no está disponible. Quítalo y agrégalo de nuevo.';
    }
    if (currentComplement.priceCents != selected.priceCents) {
      return 'Cambió el precio del complemento ${selected.label}. Quítalo y agrégalo de nuevo.';
    }
  }

  final selectedVariant = line.variant;
  if (selectedVariant == null) {
    if (current.variants.isNotEmpty) {
      return 'Ahora tiene variantes. Quítalo y agrégalo de nuevo para elegir una.';
    }
    final selectedComplementPrice = line.complements.fold<int>(
      0,
      (total, item) => total + item.priceCents,
    );
    if (current.priceCents != line.unitPriceCents - selectedComplementPrice) {
      return 'El precio cambió a ${formatMoney(current.priceCents)}. Agrégalo de nuevo para confirmarlo.';
    }
    return null;
  }

  ProductVariant? currentVariant;
  for (final variant in current.variants) {
    if (variant.label == selectedVariant.label) {
      currentVariant = variant;
      break;
    }
  }
  if (currentVariant == null || !currentVariant.isAvailable) {
    return 'La variante ya no está disponible. Quítala y vuelve a elegir.';
  }
  if (currentVariant.priceCents != selectedVariant.priceCents) {
    return 'El precio cambió a ${formatMoney(currentVariant.priceCents)}. Agrégalo de nuevo para confirmarlo.';
  }
  return null;
}
