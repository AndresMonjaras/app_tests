import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/core/errors/domain_exception.dart';
import 'package:lincefood_app/features/orders/data/memory_orders_repository.dart';
import 'package:lincefood_app/features/orders/domain/order_record.dart';
import 'package:lincefood_app/features/orders/domain/order_status.dart';
import 'package:lincefood_app/features/orders/presentation/orders_providers.dart';
import 'package:lincefood_app/features/orders/presentation/staff_orders_screen.dart';

Future<void> _montarCola(
  WidgetTester tester,
  MemoryOrdersRepository repository,
  OrderStatus status,
) async {
  repository.setOrders('estudiante', [
    OrderRecord(
      id: 'p1',
      status: status,
      ownerUid: 'estudiante',
      lines: const [],
    ),
  ]);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ordersRepositoryProvider.overrideWithValue(repository),
        staffPermissionProvider.overrideWith((ref) async => true),
        adminPermissionProvider.overrideWith((ref) async => false),
      ],
      child: const MaterialApp(home: StaffOrdersScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'exige una nota, muestra el contador y retira el pedido de la cola',
    (tester) async {
      final repository = MemoryOrdersRepository();
      addTearDown(repository.dispose);
      await _montarCola(tester, repository, OrderStatus.paid);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Rechazar'));
      await tester.pumpAndSettle();
      final confirmar = find.widgetWithText(FilledButton, 'Rechazar');
      final campo = find.byType(TextField);
      expect(tester.widget<FilledButton>(confirmar).onPressed, isNull);
      expect(find.text('0/200'), findsOneWidget);

      await tester.enterText(campo, '  café  ');
      await tester.pump();
      expect(tester.widget<FilledButton>(confirmar).onPressed, isNull);

      await tester.enterText(campo, 'a' * 201);
      await tester.pump();
      expect(find.text('200/200'), findsOneWidget);

      await tester.enterText(campo, 'Café agotado');
      await tester.pump();
      expect(find.text('12/200'), findsOneWidget);
      await tester.tap(confirmar);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('No hay pedidos pagados por atender.'), findsOneWidget);
      final pedidos = await tester.runAsync(
        () => repository.watchOrdersFor('estudiante').first,
      );
      expect(pedidos!.single.status, OrderStatus.rejected);
      expect(pedidos.single.rejectionReason, 'Café agotado');
    },
  );

  testWidgets('un error del servidor deja visible la nota para corregirla', (
    tester,
  ) async {
    final repository = _RechazoDenegado();
    addTearDown(repository.dispose);
    await _montarCola(tester, repository, OrderStatus.confirmed);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Rechazar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Producto agotado');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Rechazar'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('El pedido ya está en cocina.'),
      ),
      findsOneWidget,
    );
    expect(find.text('Producto agotado'), findsOneWidget);
    await tester.tap(find.text('Volver'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Rechazar'));
    await tester.pumpAndSettle();
    expect(find.text('Producto agotado'), findsNothing);
    expect(find.text('El pedido ya está en cocina.'), findsNothing);
  });

  testWidgets(
    'en cocina solo se puede avanzar a listo y la entrega requiere QR',
    (tester) async {
      final repository = MemoryOrdersRepository();
      addTearDown(repository.dispose);
      await _montarCola(tester, repository, OrderStatus.preparing);
      expect(find.text('Rechazar'), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'Listo'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Listo para recoger'), findsOneWidget);
      expect(find.text('Rechazar'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Entregado'), findsNothing);
    },
  );
}

class _RechazoDenegado extends MemoryOrdersRepository {
  @override
  Future<OrderRecord> rejectOrder(String orderId, String reason) async {
    throw const DomainException('El pedido ya está en cocina.');
  }
}
