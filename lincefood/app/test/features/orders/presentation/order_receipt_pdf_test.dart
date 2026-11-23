import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/cart/domain/cart.dart';
import 'package:lincefood_app/features/catalog/domain/product.dart';
import 'package:lincefood_app/features/orders/domain/order_record.dart';
import 'package:lincefood_app/features/orders/domain/order_status.dart';
import 'package:lincefood_app/features/orders/presentation/order_receipt_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('genera un PDF de ticket con texto en español', () async {
    final order = OrderRecord(
      id: 'order-1',
      folio: 'LF-000042',
      status: OrderStatus.delivered,
      lines: [
        CartLine(
          product: Product(id: 'cafe', name: 'Café', priceCents: 1250),
          quantity: 2,
        ),
      ],
      createdAt: DateTime.utc(2026, 11, 22, 12),
      totalCents: 2500,
    );

    final bytes = await buildOrderReceiptPdf(order);

    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(500));
  });
}
