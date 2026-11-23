import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/orders/domain/order_record.dart';
import 'package:lincefood_app/features/orders/domain/order_status.dart';
import 'package:lincefood_app/features/orders/presentation/order_rejection_notice.dart';
import 'package:lincefood_app/features/orders/presentation/orders_providers.dart';
import 'package:lincefood_app/features/orders/presentation/orders_screen.dart';

const _reason = 'Se agotó el pan integral.';

Future<void> _showTicket(
  WidgetTester tester,
  DateTime rejectedAt, {
  RejectionNotice? notice,
  String? uid = 'alumno',
  bool offline = false,
}) async {
  final order = OrderRecord(
    id: 'pedido-1',
    ownerUid: 'alumno',
    status: OrderStatus.rejected,
    lines: const [],
    rejectionReason: _reason,
    rejectedAt: rejectedAt,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        uidActivoProvider.overrideWithValue(uid),
        ordersStreamProvider.overrideWith((ref) => Stream.value([order])),
        rejectionNoticeProvider(order.id).overrideWith((ref) async {
          if (offline) throw StateError('Sin conexión');
          return notice;
        }),
      ],
      child: MaterialApp(theme: ThemeData.dark(), home: const OrdersScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'el rechazo muestra el motivo y deja todos los pasos pendientes',
    (tester) async {
      final rejectedAt = DateTime.now().subtract(const Duration(minutes: 9));
      await _showTicket(tester, rejectedAt);

      expect(find.text('Rechazado'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text(_reason), findsOneWidget);
      final progress = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progress.value, 0);
      expect(find.bySemanticsLabel(RegExp('paso actual')), findsNothing);
      expect(find.text('Pago confirmado'), findsNothing);
      expect(find.text('Cancelar pedido'), findsNothing);
      expect(find.text('Ver QR'), findsNothing);

      await tester.pump(const Duration(seconds: 61));
      await tester.pump();
      expect(find.text(_reason), findsNothing);
      expect(find.text('Rechazado'), findsOneWidget);
    },
  );

  testWidgets('un ticket que ya cumplió diez minutos solo muestra el estado', (
    tester,
  ) async {
    await _showTicket(
      tester,
      DateTime.now().subtract(const Duration(minutes: 10)),
    );
    expect(find.text('Rechazado'), findsOneWidget);
    expect(find.text(_reason), findsNothing);
  });

  testWidgets('ignora un registro cuyo expiresAt ya pasó', (tester) async {
    final now = DateTime.now();
    await _showTicket(
      tester,
      now.subtract(const Duration(minutes: 1)),
      notice: (reason: _reason, expiresAt: now.millisecondsSinceEpoch - 1),
    );
    expect(find.text('Rechazado'), findsOneWidget);
    expect(find.text(_reason), findsNothing);
  });

  testWidgets('lee la nota vigente del registro del usuario', (tester) async {
    final now = DateTime.now();
    const message = 'Se agotó el pedido del día.';
    await _showTicket(
      tester,
      now,
      notice: (
        reason: message,
        expiresAt: now.add(const Duration(minutes: 10)).millisecondsSinceEpoch,
      ),
    );
    expect(find.text(message), findsOneWidget);
    expect(find.text(_reason), findsNothing);
  });

  testWidgets('sin conexión usa la nota del ticket hasta el vencimiento', (
    tester,
  ) async {
    await _showTicket(
      tester,
      DateTime.now().subtract(const Duration(minutes: 9)),
      offline: true,
    );
    expect(find.text(_reason), findsOneWidget);
    await tester.pump(const Duration(minutes: 1));
    await tester.pump();
    expect(find.text(_reason), findsNothing);
  });

  for (final uid in [null, 'otra-cuenta']) {
    testWidgets('la sesión $uid no muestra la nota de otro ticket', (
      tester,
    ) async {
      await _showTicket(tester, DateTime.now(), uid: uid);
      expect(find.text(_reason), findsNothing);
    });
  }
}
