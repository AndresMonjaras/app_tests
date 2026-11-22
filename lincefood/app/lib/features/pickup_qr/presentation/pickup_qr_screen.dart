import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/errors/domain_exception.dart';
import '../domain/pickup_qr_gateway.dart';
import 'pickup_qr_providers.dart';

class PickupQrScreen extends ConsumerWidget {
  const PickupQrScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qr = ref.watch(pickupQrProvider(orderId));

    void retry() => ref.invalidate(pickupQrProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('QR de recogida')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: qr.when(
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
                        reveal.blockedReason ?? 'El QR no está disponible.',
                    onRetry: retry,
                  );
                }
                return _QrCode(pickup: token, onRefresh: retry);
              },
            ),
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
