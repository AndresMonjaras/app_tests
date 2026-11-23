import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../core/money/money.dart';
import '../domain/order_record.dart';
import 'order_receipt_pdf.dart';

class OrderReceiptScreen extends StatelessWidget {
  const OrderReceiptScreen({super.key, required this.order});

  final OrderRecord order;

  @override
  Widget build(BuildContext context) {
    final date = order.createdAt?.toLocal();
    final dateLabel = date == null
        ? 'Fecha no disponible'
        : '${date.day.toString().padLeft(2, '0')}/'
              '${date.month.toString().padLeft(2, '0')}/${date.year} · '
              '${date.hour.toString().padLeft(2, '0')}:'
              '${date.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(title: const Text('Ticket')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Lincefood',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const Text('Ticket de compra'),
                          ],
                        ),
                      ),
                      // Mojarra fija: en el recibo no se anima.
                      ExcludeSemantics(
                        child: Image.asset(
                          'assets/images/mojarra/mojarra_sola.png',
                          width: 72,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  _ReceiptDetail(label: 'Folio', value: order.displayFolio),
                  _ReceiptDetail(label: 'Fecha', value: dateLabel),
                  _ReceiptDetail(
                    label: 'Entrega',
                    value: order.pickupMode.label,
                  ),
                  _ReceiptDetail(label: 'Estado', value: 'Entregado'),
                  const Divider(height: 32),
                  for (final line in order.lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              '${line.quantity} × ${line.product.name}'
                              '${line.variant == null ? '' : ' (${line.variant!.label})'}',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(formatMoney(line.totalCents)),
                        ],
                      ),
                    ),
                  if (order.lines.isEmpty)
                    const Text('No hay detalle de productos disponible.'),
                  const Divider(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        formatMoney(order.totalCents),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: ExcludeSemantics(
                      child: Image.asset(
                        'assets/images/mojarra/mojarras_cardumen.png',
                        height: 84,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _download(context),
            icon: const Icon(Icons.download),
            label: const Text('Descargar ticket PDF'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _share(context),
            icon: const Icon(Icons.share_outlined),
            label: const Text('Compartir ticket'),
          ),
        ],
      ),
    );
  }

  Future<void> _download(BuildContext context) async {
    try {
      await Printing.layoutPdf(
        name: 'ticket-${order.displayFolio}.pdf',
        onLayout: (_) => buildOrderReceiptPdf(order),
      );
    } catch (_) {
      if (!context.mounted) return;
      _showMessage(context, 'No se pudo abrir la opción para guardar el PDF.');
    }
  }

  Future<void> _share(BuildContext context) async {
    try {
      final bytes = await buildOrderReceiptPdf(order);
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'ticket-${order.displayFolio}.pdf',
      );
    } catch (_) {
      if (!context.mounted) return;
      _showMessage(context, 'No se pudo compartir el ticket.');
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ReceiptDetail extends StatelessWidget {
  const _ReceiptDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label), const SizedBox(width: 12), Text(value)],
    ),
  );
}
