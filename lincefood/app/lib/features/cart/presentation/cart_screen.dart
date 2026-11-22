import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_router.dart';
import '../../../core/money/money.dart';
import '../../../shared/widgets/fixed_bottom_bar.dart';
import '../../orders/domain/pickup_mode.dart';
import '../../orders/presentation/order_actions_controller.dart';
import '../../orders/presentation/orders_providers.dart';
import '../../payments/presentation/payment_providers.dart';
import '../domain/cart.dart';
import 'cart_controller.dart';
import 'cart_checkout_controller.dart';

// Evita que el carrito y la barra de total se estiren en escritorio.
const _anchoMaximo = 720.0;

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider);
    final pickupMode = ref.watch(pickupModeProvider);
    final checkout = ref.watch(cartCheckoutProvider);
    final configured = ref.watch(paymentConfiguredProvider);
    final uid = ref.watch(uidActivoProvider);
    final matches = ref
        .read(cartCheckoutProvider.notifier)
        .matches(cart, uid, pickupMode);
    final serverOrder = matches ? checkout.order : null;
    final lines = serverOrder?.lines ?? cart.lines;
    final total = formatMoney(serverOrder?.totalCents ?? cart.totalCents);
    final subtotal = lines.fold<int>(0, (sum, line) => sum + line.totalCents);
    final error = checkout.message;
    final busy = checkout.isWorking;

    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Carrito')),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _anchoMaximo),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (cart.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: Text('Tu carrito está vacío.')),
                  )
                else ...[
                  for (final line in lines)
                    _CartLineTile(
                      line: line,
                      onDecrease: busy
                          ? null
                          : () => ref
                                .read(cartControllerProvider.notifier)
                                .changeQuantity(
                                  productId: line.product.id,
                                  variantLabel: line.variant?.label,
                                  quantity: line.quantity - 1,
                                ),
                      onIncrease: busy
                          ? null
                          : () => ref
                                .read(cartControllerProvider.notifier)
                                .changeQuantity(
                                  productId: line.product.id,
                                  variantLabel: line.variant?.label,
                                  quantity: line.quantity + 1,
                                ),
                      onRemove: busy
                          ? null
                          : () => ref
                                .read(cartControllerProvider.notifier)
                                .removeLine(
                                  productId: line.product.id,
                                  variantLabel: line.variant?.label,
                                ),
                    ),
                  const Divider(),
                  Text(
                    'Modalidad de recogida',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<PickupMode>(
                    segments: [
                      for (final mode in PickupMode.values)
                        ButtonSegment<PickupMode>(
                          value: mode,
                          label: Text(mode.label),
                        ),
                    ],
                    selected: {pickupMode},
                    onSelectionChanged: busy
                        ? null
                        : (selection) => ref
                              .read(pickupModeProvider.notifier)
                              .select(selection.first),
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
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
        bottomNavigationBar: cart.isEmpty
            ? null
            : FixedBottomBar(
                child: Center(
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _anchoMaximo),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Subtotal'),
                            Text(formatMoney(subtotal)),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
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
                            onPressed:
                                uid == null ||
                                    uid.isEmpty ||
                                    !configured ||
                                    busy
                                ? null
                                : () => _submit(
                                    context,
                                    ref,
                                    cart,
                                    uid,
                                    pickupMode,
                                  ),
                            child: busy
                                ? SizedBox.square(
                                    dimension: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimary,
                                      semanticsLabel: 'Procesando pago',
                                    ),
                                  )
                                : Text('Pagar $total'),
                          ),
                        ),
                      ],
                    ),
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

class _CartLineTile extends StatelessWidget {
  const _CartLineTile({
    required this.line,
    required this.onDecrease,
    required this.onIncrease,
    required this.onRemove,
  });

  final CartLine line;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final variant = line.variant == null ? '' : ' (${line.variant!.label})';
    final theme = Theme.of(context);
    final nombre = '${line.product.name}$variant';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            tooltip: 'Quitar $nombre',
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nombre, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 2),
                  Text(
                    '${formatMoney(line.unitPriceCents)} c/u',
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    'Subtotal ${formatMoney(line.totalCents)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Reducir cantidad de $nombre',
            onPressed: onDecrease,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Semantics(
              label: 'Cantidad: ${line.quantity}',
              excludeSemantics: true,
              child: Text('${line.quantity}'),
            ),
          ),
          IconButton(
            tooltip: 'Aumentar cantidad de $nombre',
            onPressed: onIncrease,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}
