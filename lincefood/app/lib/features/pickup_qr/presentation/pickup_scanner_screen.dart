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
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
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
                  _ScanOverlay(scan: scan),
                ],
              ),
            ),
            _ScanStatusPanel(scan: scan, onReset: controller.reset),
            if (!scan.delivered)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _FolioForm(
                  enabled: !scan.busy,
                  onSubmit: controller.handleFolio,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _ScanPhase { ready, processing, success, error }

_ScanPhase _phaseOf(PickupScanState scan) {
  if (scan.busy) return _ScanPhase.processing;
  if (scan.delivered) return _ScanPhase.success;
  if (scan.message != null) return _ScanPhase.error;
  return _ScanPhase.ready;
}

Color _phaseColor(ColorScheme colors, _ScanPhase phase) => switch (phase) {
  _ScanPhase.ready => Colors.white,
  _ScanPhase.processing => colors.primary,
  _ScanPhase.success => colors.primary,
  _ScanPhase.error => colors.error,
};

class _ScanOverlay extends StatelessWidget {
  const _ScanOverlay({required this.scan});

  final PickupScanState scan;

  @override
  Widget build(BuildContext context) {
    final color = _phaseColor(Theme.of(context).colorScheme, _phaseOf(scan));

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = (constraints.biggest.shortestSide * 0.68)
              .clamp(160.0, 320.0)
              .toDouble();
          return CustomPaint(
            size: constraints.biggest,
            painter: _ReticlePainter(side: side, color: color),
          );
        },
      ),
    );
  }
}

// Atenúa el exterior del recuadro y dibuja esquinas redondeadas.
class _ReticlePainter extends CustomPainter {
  const _ReticlePainter({required this.side, required this.color});

  final double side;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: size.center(Offset.zero),
        width: side,
        height: side,
      ),
      const Radius.circular(20),
    );

    final dim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(frame);
    canvas.drawPath(dim, Paint()..color = Colors.black.withValues(alpha: 0.4));

    final corner = side * 0.2;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final r = frame.outerRect;
    const rad = 20.0;

    // Esquina: tramo recto + curva, una por cada vértice.
    for (final c in [
      (r.topLeft, 1.0, 1.0),
      (r.topRight, -1.0, 1.0),
      (r.bottomLeft, 1.0, -1.0),
      (r.bottomRight, -1.0, -1.0),
    ]) {
      final p = c.$1;
      final sx = c.$2;
      final sy = c.$3;
      final path = Path()
        ..moveTo(p.dx + sx * corner, p.dy + sy * rad)
        ..lineTo(p.dx, p.dy + sy * rad)
        ..quadraticBezierTo(p.dx, p.dy, p.dx + sx * rad, p.dy)
        ..lineTo(p.dx + sx * corner, p.dy);
      canvas.drawPath(path, stroke);
    }
  }

  @override
  bool shouldRepaint(_ReticlePainter old) =>
      old.side != side || old.color != color;
}

class _ScanStatusPanel extends StatelessWidget {
  const _ScanStatusPanel({required this.scan, required this.onReset});

  final PickupScanState scan;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final phase = _phaseOf(scan);

    final (icon, title, detail, accent) = switch (phase) {
      _ScanPhase.ready => (
        Icons.qr_code_scanner,
        'Listo para escanear',
        'Coloca el QR del cliente dentro del recuadro.',
        colors.onSurfaceVariant,
      ),
      _ScanPhase.processing => (
        Icons.hourglass_top,
        'Procesando…',
        'Validando el código, espera un momento.',
        colors.primary,
      ),
      _ScanPhase.success => (
        Icons.check_circle_outline,
        'Entrega exitosa',
        scan.message ?? '',
        colors.primary,
      ),
      _ScanPhase.error => (
        Icons.error_outline,
        'No se pudo entregar',
        scan.message ?? '',
        colors.error,
      ),
    };

    return Semantics(
      liveRegion: true,
      container: true,
      child: Material(
        color: colors.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (phase == _ScanPhase.processing)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(),
                ),
              Row(
                children: [
                  Icon(icon, size: 36, color: accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: phase == _ScanPhase.error ? accent : null,
                          ),
                        ),
                        if (detail.isNotEmpty)
                          Text(detail, style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ),
              if (scan.message != null) ...[
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: onReset,
                  child: const Text('Escanear otro'),
                ),
              ],
            ],
          ),
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
