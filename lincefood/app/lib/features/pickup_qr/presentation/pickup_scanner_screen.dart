import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'pickup_qr_providers.dart';

class PickupScannerScreen extends ConsumerWidget {
  const PickupScannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scan = ref.watch(pickupScanControllerProvider);
    final controller = ref.read(pickupScanControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Entregar pedido')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: MobileScanner(
                onDetect: (capture) {
                  for (final barcode in capture.barcodes) {
                    final code = barcode.rawValue;
                    if (barcode.format == BarcodeFormat.qrCode &&
                        code != null) {
                      controller.handleCode(code);
                      break;
                    }
                  }
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (scan.busy) const LinearProgressIndicator(),
                  if (scan.delivered)
                    Icon(
                      Icons.check_circle_outline,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  if (scan.message != null) ...[
                    Text(
                      scan.message!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (scan.message != null)
                    FilledButton(
                      onPressed: controller.reset,
                      child: const Text('Escanear otro'),
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
