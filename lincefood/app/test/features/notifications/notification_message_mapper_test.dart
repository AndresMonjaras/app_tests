import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/notifications/domain/notification_message_mapper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('mapea pedido listo al texto genérico del seed', () async {
    final seed = jsonDecode(
      await rootBundle.loadString(notificationCopySeedAsset),
    ) as Map<String, dynamic>;
    final mapper = await NotificationMessageMapper.loadSeed();

    final notice = mapper.mapPayload({
      'tipo': 'pedido_listo',
      'folio': 'F-1024',
      'importe': '950.00',
      'estado': 'listo',
    });
    final genericNotice = mapper.mapPayload({'tipo': 'pedido_listo'});

    expect(notice, isNotNull);
    expect(genericNotice, isNotNull);
    expect(notice!.title, seed['pedido_listo']['titulo']);
    expect(notice.body, seed['pedido_listo']['cuerpo']);
    expect(notice.body, genericNotice!.body);
    expect(notice.title, isNot(contains('F-1024')));
    expect(notice.body, isNot(contains('950.00')));
  });

  test('ignora payloads que no corresponden al seed público', () async {
    final mapper = await NotificationMessageMapper.loadSeed();

    expect(mapper.mapPayload({'tipo': 'pedido_individual'}), isNull);
  });

  test('el aviso de rechazo en primer plano muestra la nota y abre pedidos', () async {
    final mapper = await NotificationMessageMapper.loadSeed();
    const reason = 'Se agotó el platillo solicitado.';
    final notice = mapper.mapPayload({
      'type': 'pedido_rechazado',
      'orderId': 'pedido-42',
      'customText': reason,
    });

    expect(notice?.title, 'Pedido rechazado');
    expect(notice?.body, reason);
    expect(notice?.target, NotificationTarget.orders);
    expect(notice?.orderId, 'pedido-42');
  });

  test(
    'mapea las notificaciones de pedido y conserva solo el ID técnico',
    () async {
      final mapper = await NotificationMessageMapper.loadSeed();

      for (final type in [
        'pedido_registrado',
        'pedido_en_cocina',
        'pedido_listo',
      ]) {
        final notice = mapper.mapPayload({
          'type': type,
          'orderId': 'pedido-42',
          'folio': 'LF-12345678',
          'importe': '950.00',
        });

        expect(notice, isNotNull);
        expect(
          notice!.target,
          type == 'pedido_listo'
              ? NotificationTarget.pickupQr
              : NotificationTarget.orders,
        );
        expect(notice.orderId, 'pedido-42');
        expect(notice.title, isNot(contains('LF-12345678')));
        expect(notice.body, isNot(contains('950.00')));
      }
    },
  );
}
