import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/core/errors/domain_exception.dart';
import 'package:lincefood_app/core/money/money.dart';
import 'package:lincefood_app/features/cart/domain/cart.dart';
import 'package:lincefood_app/features/catalog/data/in_memory_catalog_repository.dart';
import 'package:lincefood_app/features/catalog/domain/product.dart';
import 'package:lincefood_app/features/orders/domain/order_record.dart';
import 'package:lincefood_app/features/orders/domain/order_status.dart';

void main() {
  group('carrito y variantes', () {
    test('formatea dinero sin conversiones de punto flotante', () {
      expect(formatMoney(1299), r'$12.99 MXN');
      expect(formatMoney(123456789), r'$1,234,567.89 MXN');
      expect(formatMoney(-500), r'-$5.00 MXN');
    });

    test('suma las líneas usando centavos enteros', () {
      final coffee = Product(id: 'cafe', name: 'Café', priceCents: 125);
      final bread = Product(id: 'pan', name: 'Pan', priceCents: 240);
      final cart = Cart([
        CartLine(product: coffee, quantity: 2),
        CartLine(product: bread, quantity: 1),
      ]);

      expect(cart.totalCents, 490);
    });

    test('usa el precio de la variante elegida', () {
      final large = ProductVariant(label: 'Grande', priceCents: 375);
      final coffee = Product(
        id: 'cafe',
        name: 'Café',
        priceCents: 250,
        variants: [
          ProductVariant(label: 'Chico', priceCents: 250),
          large,
        ],
      );
      final line = CartLine(product: coffee, quantity: 2, variant: large);

      expect(line.unitPriceCents, 375);
      expect(line.totalCents, 750);
    });

    test('rechaza etiquetas vacías o mayores de 40 caracteres', () {
      expect(
        () => ProductVariant(label: '   ', priceCents: 100),
        throwsA(isA<DomainException>()),
      );
      expect(
        () => ProductVariant(label: 'a' * 41, priceCents: 100),
        throwsA(isA<DomainException>()),
      );
      expect(ProductVariant(label: 'a' * 40, priceCents: 100).label.length, 40);
    });

    test('rechaza más de seis variantes', () {
      final variants = [
        for (var index = 0; index < 7; index++)
          ProductVariant(label: 'Opción ${index + 1}', priceCents: 100),
      ];

      expect(
        () => Product(
          id: 'bebida',
          name: 'Bebida',
          priceCents: 100,
          variants: variants,
        ),
        throwsA(isA<DomainException>()),
      );
    });

    test(
      'el repositorio en memoria devuelve los productos recibidos',
      () async {
        final product = Product(id: 'cafe', name: 'Café', priceCents: 125);
        final repository = InMemoryCatalogRepository([product]);

        expect(await repository.fetchProducts(), [product]);
      },
    );
  });

  group('estados del pedido', () {
    test('expone los códigos de estado definidos por el contrato', () {
      expect(OrderStatus.values.map((status) => status.code), [
        'payment_pending',
        'paid',
        'confirmed',
        'preparing',
        'ready',
        'delivered',
        'incident',
      ]);
    });

    test('permite avanzar por los estados del flujo', () {
      var order = OrderRecord(
        id: 'pedido-1',
        status: OrderStatus.paymentPending,
        lines: const [],
      );

      for (final status in OrderStatus.values.skip(1)) {
        order = order.transitionTo(status);
      }

      expect(order.status, OrderStatus.incident);
    });

    test('rechaza volver a un estado anterior o repetir el actual', () {
      final order = OrderRecord(
        id: 'pedido-1',
        status: OrderStatus.confirmed,
        lines: const [],
      );

      expect(
        () => order.transitionTo(OrderStatus.paid),
        throwsA(isA<DomainException>()),
      );
      expect(
        () => order.transitionTo(OrderStatus.confirmed),
        throwsA(isA<DomainException>()),
      );
    });

    test('bloquea cancelación desde preparing y edición de líneas desde paid', () {
      final preparing = OrderRecord(
        id: 'pedido-1',
        status: OrderStatus.preparing,
        lines: const [],
      );
      final paid = OrderRecord(
        id: 'pedido-2',
        status: OrderStatus.paid,
        lines: const [],
      );

      expect(() => preparing.cancel(), throwsA(isA<DomainException>()));
      expect(() => paid.editLines(const []), throwsA(isA<DomainException>()));
    });

    test('permite cancelar desde paid y confirmed antes de cocina', () {
      for (final status in [OrderStatus.paid, OrderStatus.confirmed]) {
        final order = OrderRecord(id: 'pedido-1', status: status, lines: const []);
        expect(order.cancel().isCancelled, isTrue);
      }
    });

    test('permite cancelar mientras el pago sigue pendiente', () {
      final order = OrderRecord(
        id: 'pedido-1',
        status: OrderStatus.paymentPending,
        lines: const [],
      );

      expect(order.cancel().isCancelled, isTrue);
    });
  });
}
