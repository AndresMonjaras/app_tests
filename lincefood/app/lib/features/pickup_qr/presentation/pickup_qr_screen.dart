import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/errors/domain_exception.dart';
import '../../orders/domain/order_status.dart';
import '../../orders/presentation/orders_providers.dart';
import '../domain/pickup_qr_gateway.dart';
import 'pickup_qr_providers.dart';

class PickupQrScreen extends ConsumerWidget {
  const PickupQrScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersStreamProvider);
    final isDelivered =
        orders.value?.any(
          (order) =>
              order.id == orderId && order.status == OrderStatus.delivered,
        ) ??
        false;
    final canShow =
        orders.value?.any(
          (order) =>
              order.id == orderId &&
              !order.isCancelled &&
              order.status == OrderStatus.ready,
        ) ??
        false;
    final qr = canShow ? ref.watch(pickupQrProvider(orderId)) : null;

    void retry() => ref.invalidate(pickupQrProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('QR de recogida')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: orders.hasError
                ? _QrMessage(
                    message: 'No se pudo verificar el estado del pedido.',
                    onRetry: () => ref.invalidate(ordersStreamProvider),
                  )
                : qr?.when(
                        loading: () => const CircularProgressIndicator(
                          semanticsLabel: 'Generando QR de recogida',
                        ),
                        error: (error, _) => _QrMessage(
                          message: error is DomainException
                              ? error.message
                              : 'No se pudo generar el QR. Inténtalo de nuevo.',
                          onRetry: retry,
                        ),
                        data: (reveal) {
                          final token = reveal.token;
                          if (token == null) {
                            return _QrMessage(
                              message:
                                  reveal.blockedReason ??
                                  'El QR no está disponible.',
                              onRetry: retry,
                            );
                          }
                          return _QrCode(pickup: token, onRefresh: retry);
                        },
                      ) ??
                      (orders.isLoading
                          ? const CircularProgressIndicator()
                          : Text(
                              isDelivered ? 'El pedido ya fue entregado.' : 'El QR solo está disponible para pedidos listos.',
                            )),
          ),
        ),
      ),
    );
  }
}

class _QrCode extends StatelessWidget {
  const _QrCode({required this.pickup, required this.onRefresh});

  final PickupQrToken pickup;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: QrImageView(
            data: pickup.token,
            size: 240,
            semanticsLabel: 'Código QR de recogida del pedido',
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Válido hasta ${_formatTime(pickup.expiresAt)}. '
          'Muéstralo al personal para recoger tu pedido.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
          label: const Text('Generar nuevo QR'),
        ),
      ],
    );
  }

  static String _formatTime(DateTime value) {
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

class _QrMessage extends StatelessWidget {
  const _QrMessage({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.lock_outline,
          size: 48,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
      ],
    );
  }
}
