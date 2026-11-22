import 'dart:convert';

import 'package:flutter/services.dart';

const notificationCopySeedAsset = 'assets/data/notificaciones.seed.json';

enum NotificationTarget { catalog, orders }

class NotificationPresentation {
  const NotificationPresentation({
    required this.key,
    required this.title,
    required this.body,
    required this.target,
    this.orderId,
  });

  final String key;
  final String title;
  final String body;
  final NotificationTarget target;
  final String? orderId;
}

class NotificationMessageMapper {
  NotificationMessageMapper(this._copies);

  final Map<String, Map<String, String>> _copies;

  static Future<NotificationMessageMapper> loadSeed() async {
    final contents = await rootBundle.loadString(notificationCopySeedAsset);
    final decoded = jsonDecode(contents);
    if (decoded is! Map) {
      throw const FormatException('El seed de notificaciones no es válido.');
    }

    final copies = <String, Map<String, String>>{};
    for (final entry in decoded.entries) {
      if (entry.key is! String || entry.value is! Map) continue;
      final copy = entry.value as Map;
      final title = copy['titulo'];
      final body = copy['cuerpo'];
      if (title is String && body is String) {
        copies[entry.key as String] = {'titulo': title, 'cuerpo': body};
      }
    }
    return NotificationMessageMapper(copies);
  }

  NotificationPresentation? mapPayload(Map<String, Object?> payload) {
    final key = _payloadKey(payload);
    if (key == null) return null;

    final copy = _copies[key];
    if (copy == null) return null;
    final customText = payload['customText'];
    final customBody =
        key == 'cafeteria_avisos' &&
            customText is String &&
            customText.trim().isNotEmpty &&
            customText.trim().runes.length <= 120
        ? customText.trim()
        : copy['cuerpo']!;

    return NotificationPresentation(
      key: key,
      title: copy['titulo']!,
      body: customBody,
      target: key.startsWith('pedido_')
          ? NotificationTarget.orders
          : NotificationTarget.catalog,
      orderId: payload['orderId'] is String
          ? payload['orderId'] as String
          : null,
    );
  }

  String? _payloadKey(Map<String, Object?> payload) {
    for (final field in const ['tipo', 'topic', 'type']) {
      final value = payload[field];
      if (value is String && _copies.containsKey(value)) return value;
    }
    return null;
  }
}
