import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/app/app_router.dart';
import 'package:lincefood_app/features/orders/data/memory_orders_repository.dart';
import 'package:lincefood_app/features/orders/presentation/orders_providers.dart';
import 'package:lincefood_app/features/orders/presentation/orders_screen.dart';
import 'package:lincefood_app/features/orders/presentation/staff_orders_screen.dart';

void main() {
  for (final role in ['staff', 'admin', 'estudiante']) {
    testWidgets('acceso desde Mi ticket con rol $role', (tester) async {
      final repository = MemoryOrdersRepository();
      addTearDown(repository.dispose);
      final claims = {if (role != 'estudiante') role: true};
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            orderClaimsProvider.overrideWith((ref) => Stream.value(claims)),
            ordersRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            home: const OrdersScreen(),
            routes: {AppRouter.staffOrders: (_) => const StaffOrdersScreen()},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final entry = find.byTooltip('Panel de cafetería');
      if (role == 'estudiante') {
        expect(entry, findsNothing);
        Navigator.of(tester.element(find.byType(OrdersScreen)))
            .pushNamed(AppRouter.staffOrders);
        await tester.pumpAndSettle();
        expect(
          find.text('Esta sección es solo para personal de cafetería.'),
          findsOneWidget,
        );
        expect(find.text('Escanear QR'), findsNothing);
        return;
      }
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(find.text('No hay pedidos pagados por atender.'), findsOneWidget);
      expect(find.text('Escanear QR'), findsOneWidget);
    });
  }
}
