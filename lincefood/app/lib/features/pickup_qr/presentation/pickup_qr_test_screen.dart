import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../biometrics/biometric_protection.dart';
import 'pickup_qr_providers.dart';
import 'pickup_scanner_screen.dart';

class PickupQrTestScreen extends ConsumerStatefulWidget {
  const PickupQrTestScreen({super.key, this.openedFromQr = false});

  final bool openedFromQr;

  @override
  ConsumerState<PickupQrTestScreen> createState() => _PickupQrTestScreenState();
}

class _PickupQrTestScreenState extends ConsumerState<PickupQrTestScreen> {
  bool _busy = false;
  bool _authorized = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    if (widget.openedFromQr) {
      _authorized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(
            ref
                .read(pickupScanControllerProvider.notifier)
                .handleCode(pickupQrTestCode),
          );
        }
      });
    }
  }

  Future<void> _authorizeQr() async {
    ref.read(pickupScanControllerProvider.notifier).reset();
    setState(() => _busy = true);
    final authorized = await ref
        .read(biometricQrProtectionServiceProvider)
        .authorizeQrReveal(protectionEnabled: true);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _authorized = authorized;
      _message = authorized ? null : 'La huella no fue confirmada.';
    });
  }

  Future<void> _simulateRead() async {
    await ref
        .read(pickupScanControllerProvider.notifier)
        .handleCode(pickupQrTestCode);
  }

  void _openScanner() {
    ref.read(pickupScanControllerProvider.notifier).reset();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PickupScannerScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scan = ref.watch(pickupScanControllerProvider);
    if (!kDebugMode) {
      return const Scaffold(
        body: Center(
          child: Text('Esta función solo está disponible en pruebas.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.openedFromQr
              ? 'QR de prueba recibido'
              : 'Prueba temporal de QR',
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (widget.openedFromQr) ...[
                  const Icon(Icons.check_circle_outline, size: 72),
                  const SizedBox(height: 16),
                  Text(
                    scan.message ?? 'QR de prueba recibido; registrando…',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Resultado local de prueba. No modifica pedidos en Firebase.',
                    textAlign: TextAlign.center,
                  ),
                ] else ...[
                  const Text(
                    'La prueba solicita la huella y muestra un QR local. Escanéalo con la cámara de otro dispositivo para abrir Lincefood y marcarlo entregado solo en pantalla; no modifica Firebase.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                ],
                if (!widget.openedFromQr && !_authorized)
                  FilledButton.icon(
                    onPressed: _busy ? null : _authorizeQr,
                    icon: const Icon(Icons.fingerprint),
                    label: Text(_busy ? 'Esperando huella…' : 'Probar huella'),
                  )
                else if (!widget.openedFromQr) ...[
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: QrImageView(
                        data: pickupQrTestCode,
                        size: 240,
                        semanticsLabel: 'Código QR temporal de prueba',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Código de prueba; no corresponde a un pedido real.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _simulateRead,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Simular lectura del QR'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _openScanner,
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Abrir lector de prueba'),
                  ),
                ],
                if (!widget.openedFromQr &&
                    (_message != null || scan.message != null)) ...[
                  const SizedBox(height: 16),
                  Text(scan.message ?? _message!, textAlign: TextAlign.center),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
