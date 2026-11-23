import 'package:flutter/material.dart';

import '../../../core/money/money.dart';
import '../../orders/domain/pickup_mode.dart';
import '../domain/cart.dart';

/// Muestra el resumen del pedido antes de pagar.
///
/// Devuelve true solo si el alumno confirma. Una vez pagado y enviado a la
/// cafetería, el pedido no admite cambios ni cancelación.
Future<bool> showOrderConfirmationDialog(
  BuildContext context, {
  required Cart cart,
  required PickupMode pickupMode,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) =>
        _OrderConfirmationDialog(cart: cart, pickupMode: pickupMode),
  );
  return confirmed ?? false;
}

class _OrderConfirmationDialog extends StatelessWidget {
  const _OrderConfirmationDialog({
    required this.cart,
    required this.pickupMode,
  });

  final Cart cart;
  final PickupMode pickupMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final itemsLabel = cart.totalItems == 1
        ? '1 producto'
        : '${cart.totalItems} productos';

    return AlertDialog(
      title: const Text('Revisa tu pedido'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(itemsLabel),
            const SizedBox(height: 4),
            Text('Recogida: ${pickupMode.label}'),
            const SizedBox(height: 4),
            Text(
              'Total: ${formatMoney(cart.totalCents)}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Al confirmar el pago, el pedido se envía a la cafetería. '
                'Después no podrás cambiarlo ni cancelarlo desde la app.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Volver'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Confirmar y pagar'),
        ),
      ],
    );
  }
}
