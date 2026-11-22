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
                  if (capture.barcodes.isEmpty) return;
                  final code = capture.barcodes.first.rawValue;
                  if (code != null) controller.handleCode(code);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (scan.busy) const LinearProgressIndicator(),
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
                  if (!scan.delivered) ...[
                    const SizedBox(height: 16),
                    _FolioForm(
                      enabled: !scan.busy,
                      onSubmit: controller.handleFolio,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Alternativa cuando la cámara falla: el personal escribe el folio del pedido.
class _FolioForm extends StatefulWidget {
  const _FolioForm({required this.enabled, required this.onSubmit});

  final bool enabled;
  final Future<void> Function(String folio) onSubmit;

  @override
  State<_FolioForm> createState() => _FolioFormState();
}

class _FolioFormState extends State<_FolioForm> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final folio = _controller.text;
    if (folio.trim().isEmpty) return;
    widget.onSubmit(folio);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            enabled: widget.enabled,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Folio del pedido',
              hintText: 'LF-XXXXXXXX',
            ),
            onSubmitted: (_) => _submit(),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: widget.enabled ? _submit : null,
          child: const Text('Validar folio'),
        ),
      ],
    );
  }
}
