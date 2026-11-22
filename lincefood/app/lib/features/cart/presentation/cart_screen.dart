import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../shared/widgets/fixed_bottom_bar.dart';
import '../../orders/domain/pickup_mode.dart';
import '../../orders/presentation/order_actions_controller.dart';
import '../../orders/presentation/orders_providers.dart';
import '../../payments/presentation/payment_providers.dart';
import '../../payments/presentation/payment_screen.dart';
import '../domain/cart.dart';
import 'cart_controller.dart';

// Evita que el carrito y la barra de total se estiren en escritorio.
const _anchoMaximo = 720.0;

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider);
    final pickupMode = ref.watch(pickupModeProvider);
    final actionState = ref.watch(orderActionsProvider);
    final uid = ref.watch(uidActivoProvider);

    return Scaffold(
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
                for (final line in cart.lines)
                  _CartLineTile(
                    line: line,
                    onDecrease: () => ref
                        .read(cartControllerProvider.notifier)
                        .changeQuantity(
                          productId: line.product.id,
                          variantLabel: line.variant?.label,
                          quantity: line.quantity - 1,
                        ),
                    onIncrease: () => ref
                        .read(cartControllerProvider.notifier)
                        .changeQuantity(
                          productId: line.product.id,
                          variantLabel: line.variant?.label,
                          quantity: line.quantity + 1,
                        ),
                    onRemove: () => ref
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
                  onSelectionChanged: (selection) =>
                      ref.read(pickupModeProvider.notifier).select(selection.first),
                ),
                if (uid == null || uid.isEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Inicia sesión para confirmar tu pedido.'),
                ],
                if (actionState.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    actionState.errorMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      // El total y la confirmación quedan fijos al pie para no perderlos al scroll.
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
                          Text(
                            'Total',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            formatMoney(cart.totalCents),
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
                              uid == null || uid.isEmpty || actionState.isWorking
                              ? null
                              : () => _submit(context, ref, cart, uid, pickupMode),
                          child: actionState.isWorking
                              ? const SizedBox.square(
                                  dimension: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Confirmar pedido'),
                        ),
                      ),
                    ],
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
    final order = await ref
        .read(orderActionsProvider.notifier)
        .submitOrder(ownerUid: uid, cart: cart, pickupMode: pickupMode);
    if (order == null || !context.mounted) return;

    ref.read(cartControllerProvider.notifier).clear();
    ref.read(paymentControllerProvider.notifier).reset();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            PaymentScreen(orderId: order.id, totalCents: order.totalCents),
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
  });

  final CartLine line;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final variant = line.variant == null ? '' : ' (${line.variant!.label})';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text('${line.product.name}$variant'),
      subtitle: Text(
        '${formatMoney(line.unitPriceCents)} c/u · ${formatMoney(line.totalCents)}',
      ),
      leading: IconButton(
        tooltip: 'Quitar producto',
        onPressed: onRemove,
        icon: const Icon(Icons.delete_outline),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Reducir cantidad',
            onPressed: onDecrease,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text('${line.quantity}'),
          IconButton(
            tooltip: 'Aumentar cantidad',
            onPressed: onIncrease,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}
