import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/notifications/data/notification_inbox_gateway.dart';
import 'package:lincefood_app/features/notifications/domain/notification_inbox_item.dart';
import 'package:lincefood_app/features/notifications/presentation/notification_preferences_controller.dart';
import 'package:lincefood_app/features/notifications/presentation/notifications_inbox_screen.dart';

NotificationInboxItem _aviso(String id, {bool leido = false, String? pedido}) {
  return NotificationInboxItem(
    id: id,
    type: pedido == null ? 'cafeteria_avisos' : 'pedido_listo',
    title: 'Título $id',
    body: 'Cuerpo $id',
    createdAt: DateTime.utc(2026, 11, 22, 12).millisecondsSinceEpoch,
    isRead: leido,
    orderId: pedido,
  );
}

Future<void> _montar(
  WidgetTester tester,
  _FakeInboxGateway gateway,
  List<NotificationInboxItem> items,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        notificationUserIdProvider.overrideWith((ref) => 'usuario-1'),
        notificationInboxGatewayProvider.overrideWithValue(gateway),
        notificationInboxProvider.overrideWith((ref) => Stream.value(items)),
      ],
      child: const MaterialApp(home: NotificationsInboxScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('muestra el contador de no leídos y marca todos como leídos', (
    tester,
  ) async {
    final gateway = _FakeInboxGateway();
    await _montar(tester, gateway, [
      _aviso('a'),
      _aviso('b', leido: true),
      _aviso('c'),
    ]);

    expect(find.text('2 sin leer'), findsOneWidget);
    await tester.tap(find.text('Marcar todos'));
    await tester.pumpAndSettle();

    expect(gateway.markedAll, ['a', 'c']);
  });

  testWidgets('marcar un aviso como leído lo envía al gateway', (tester) async {
    final gateway = _FakeInboxGateway();
    await _montar(tester, gateway, [_aviso('a')]);

    await tester.tap(find.text('Título a'));
    await tester.pumpAndSettle();

    expect(gateway.markedOne, ['a']);
  });

  testWidgets('sin avisos muestra un mensaje claro', (tester) async {
    await _montar(tester, _FakeInboxGateway(), const []);

    expect(find.text('Todavía no tienes avisos.'), findsOneWidget);
    expect(find.text('Marcar todos'), findsNothing);
  });
}

class _FakeInboxGateway implements NotificationInboxGateway {
  final List<String> markedOne = [];
  List<String> markedAll = [];

  @override
  Stream<List<NotificationInboxItem>> watch(String uid) =>
      Stream.value(const []);

  @override
  Future<void> markAsRead(String uid, String notificationId) async {
    markedOne.add(notificationId);
  }

  @override
  Future<void> markAllAsRead(
    String uid,
    Iterable<String> notificationIds,
  ) async {
    markedAll = notificationIds.toList();
  }
}
