import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/money/money.dart';
import '../domain/order_record.dart';

Future<Uint8List> buildOrderReceiptPdf(OrderRecord order) async {
  final fontData = await rootBundle.load('assets/fonts/PlusJakartaSans.ttf');
  final font = pw.Font.ttf(fontData);
  final document = pw.Document(
    theme: pw.ThemeData.withFont(base: font, bold: font),
  );
  final fish = pw.MemoryImage(
    (await rootBundle.load('assets/images/mojarra/mojarra_sola.png')).buffer
        .asUint8List(),
  );
  final school = pw.MemoryImage(
    (await rootBundle.load('assets/images/mojarra/mojarras_cardumen.png'))
        .buffer
        .asUint8List(),
  );
  final date = order.createdAt?.toLocal();
  final dateLabel = date == null
      ? 'Fecha no disponible'
      : '${date.day.toString().padLeft(2, '0')}/'
            '${date.month.toString().padLeft(2, '0')}/${date.year} '
            '${date.hour.toString().padLeft(2, '0')}:'
            '${date.minute.toString().padLeft(2, '0')}';

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              'Lincefood · Ticket de compra',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
            pw.Image(fish, width: 70),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Text('Folio: ${order.displayFolio}'),
        pw.Text('Fecha: $dateLabel'),
        pw.Text('Entrega: ${order.pickupMode.label}'),
        pw.SizedBox(height: 20),
        pw.TableHelper.fromTextArray(
          headers: const ['Producto', 'Cantidad', 'Importe'],
          data: [
            for (final line in order.lines)
              [
                '${line.product.name}'
                    '${line.variant == null ? '' : ' (${line.variant!.label})'}',
                '${line.quantity}',
                formatMoney(line.totalCents),
              ],
          ],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          cellPadding: const pw.EdgeInsets.all(8),
        ),
        pw.SizedBox(height: 16),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Total: ${formatMoney(order.totalCents)}',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.SizedBox(height: 20),
        pw.Text('Estado: Entregado'),
        pw.Text('Gracias por tu compra.'),
        pw.SizedBox(height: 12),
        pw.Center(child: pw.Image(school, height: 90)),
      ],
    ),
  );

  return document.save();
}
