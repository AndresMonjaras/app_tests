import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/notifications/data/notification_inbox_gateway.dart';
import 'package:lincefood_app/features/notifications/data/notification_tip_dismissals_gateway.dart';
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
  List<NotificationInboxItem> items, {
  Set<String> dismissed = const {},
  _FakeDismissalsGateway? dismissals,
  Map<String, WidgetBuilder> routes = const {},
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        notificationUserIdProvider.overrideWith((ref) => 'usuario-1'),
        notificationInboxGatewayProvider.overrideWithValue(gateway),
        notificationInboxProvider.overrideWith((ref) => Stream.value(items)),
        notificationTipDismissalsGatewayProvider.overrideWithValue(
          dismissals ?? _FakeDismissalsGateway(),
        ),
        dismissedTipIdsProvider.overrideWith((ref) => Stream.value(dismissed)),
      ],
      child: MaterialApp(
        home: const NotificationsInboxScreen(),
        routes: routes,
      ),
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

  testWidgets('el aviso de rechazo muestra la nota y abre su pedido', (
    tester,
  ) async {
    const notice = NotificationInboxItem(
      id: 'aviso-1',
      type: 'pedido_rechazado',
      title: 'Pedido rechazado',
      body: 'Se agotó el platillo solicitado.',
      createdAt: 1000,
      isRead: false,
      orderId: 'pedido-17',
    );
    final gateway = _FakeInboxGateway();
    await _montar(
      tester,
      gateway,
      [notice],
      routes: {
        '/orders': (_) => const Scaffold(body: Text('Ticket del pedido')),
      },
    );

    final title = find.text('Pedido rechazado');
    await tester.scrollUntilVisible(title, 180);
    expect(title, findsOneWidget);
    expect(find.text('Se agotó el platillo solicitado.'), findsOneWidget);
    await tester.tap(title);
    await tester.pumpAndSettle();

    final route = ModalRoute.of(tester.element(find.text('Ticket del pedido')));
    expect(route?.settings.name, '/orders');
    expect(route?.settings.arguments, {'orderId': 'pedido-17'});
    expect(gateway.markedOne, ['aviso-1']);
  });

  testWidgets('muestra los consejos y no muestra los que el usuario eliminó', (
    tester,
  ) async {
    await _montar(
      tester,
      _FakeInboxGateway(),
      const [],
      dismissed: {'tip_receso'},
    );

    expect(find.text('Consejos de la cafetería'), findsOneWidget);
    expect(
      find.text('Realiza tu pedido antes del receso para evitar filas.'),
      findsNothing,
    );
    expect(
      find.text('Consulta el menú para conocer los platillos disponibles.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.close), findsNWidgets(4));
  });

  testWidgets('eliminar un consejo lo guarda para el usuario', (tester) async {
    final dismissals = _FakeDismissalsGateway();
    await _montar(
      tester,
      _FakeInboxGateway(),
      const [],
      dismissals: dismissals,
    );

    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();

    expect(dismissals.dismissed, ['usuario-1:tip_receso']);
  });

  testWidgets('sin avisos muestra un mensaje claro', (tester) async {
    await _montar(tester, _FakeInboxGateway(), const []);

    expect(find.text('Todavía no tienes avisos.'), findsNothing);
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

class _FakeDismissalsGateway implements NotificationTipDismissalsGateway {
  final List<String> dismissed = [];

  @override
  Stream<Set<String>> watch(String uid) => Stream.value(const {});

  @override
  Future<void> dismiss(String uid, String tipId) async {
    dismissed.add('$uid:$tipId');
  }
}
