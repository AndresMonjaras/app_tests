import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/notifications/domain/notification_inbox_item.dart';

void main() {
  test('lee una notificación de pedido y su estado de lectura', () {
    final item = NotificationInboxItem.fromMap('aviso-1', {
      'type': 'pedido_listo',
      'title': 'Pedido listo',
      'body': 'Puedes recogerlo.',
      'createdAt': 1234,
      'isRead': true,
      'orderId': 'pedido-1',
    });

    expect(item, isNotNull);
    expect(item!.id, 'aviso-1');
    expect(item.orderId, 'pedido-1');
    expect(item.isRead, isTrue);
  });

  test('ignora registros incompletos del historial', () {
    expect(
      NotificationInboxItem.fromMap('aviso-incompleto', {'title': 'Aviso'}),
      isNull,
    );
  });
}
