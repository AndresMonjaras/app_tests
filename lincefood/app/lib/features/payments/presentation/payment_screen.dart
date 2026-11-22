import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../domain/payment_state.dart';
import 'payment_providers.dart';
import '../../orders/presentation/orders_screen.dart';

class PaymentScreen extends ConsumerWidget {
  const PaymentScreen({
    required this.orderId,
    required this.totalCents,
    super.key,
  });

  final String orderId;
  final int totalCents;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(paymentControllerProvider, (previous, next) {
      if (next.status == PaymentStatus.esperandoConfirmacion &&
          previous?.status != PaymentStatus.esperandoConfirmacion) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => OrdersScreen(orderId: orderId),
          ),
        );
      }
    });

    final isConfigured = ref.watch(paymentConfiguredProvider);
    final paymentState = ref.watch(paymentControllerProvider);
    final isProcessing = paymentState.status == PaymentStatus.procesando;
    final isAwaitingConfirmation =
        paymentState.status == PaymentStatus.esperandoConfirmacion;

    return Scaffold(
      appBar: AppBar(title: const Text('Pago')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Total a pagar'),
            const SizedBox(height: 8),
            Text(
              formatMoney(totalCents),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (!isConfigured) ...[
              const SizedBox(height: 16),
              const Text('Pagos no configurados'),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: !isConfigured || isProcessing || isAwaitingConfirmation
                  ? null
                  : () => ref
                        .read(paymentControllerProvider.notifier)
                        .pay(orderId: orderId),
              child: isProcessing
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Pagar ahora'),
                      ],
                    )
                  : Text(
                      isAwaitingConfirmation ? 'Pago enviado' : 'Pagar ahora',
                    ),
            ),
            if (isAwaitingConfirmation) ...[
              const SizedBox(height: 16),
              const Text(
                'Pago enviado. Confirmaremos tu pedido cuando Stripe lo verifique.',
                textAlign: TextAlign.center,
              ),
            ],
            if (paymentState.message case final message?) ...[
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}
