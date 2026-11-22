import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalAdviceScheduler {
  LocalAdviceScheduler(this._client);

  static const notificationId = 48120;

  final LocalAdviceNotificationClient _client;

  Future<void> scheduleHourlyAdvice() => _client.scheduleHourlyAdvice();

  Future<void> cancel() => _client.cancelAdvice();
}

abstract interface class LocalAdviceNotificationClient {
  Future<void> scheduleHourlyAdvice();

  Future<void> cancelAdvice();
}

class FlutterLocalAdviceNotificationClient
    implements LocalAdviceNotificationClient {
  FlutterLocalAdviceNotificationClient(this._notifications);

  static const channelId = 'avisos_cafeteria';
  static const channelName = 'Avisos de la cafetería';
  static const channelDescription = 'Avisos de la cafetería Lincefood';

  final FlutterLocalNotificationsPlugin _notifications;

  @override
  Future<void> scheduleHourlyAdvice() => _notifications.periodicallyShow(
    id: LocalAdviceScheduler.notificationId,
    repeatInterval: RepeatInterval.hourly,
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_notification',
      ),
      iOS: DarwinNotificationDetails(),
    ),
    title: 'Consejo de cafetería',
    body: 'Consulta el menú antes de llegar para elegir con calma.',
    payload: jsonEncode({'type': 'cafeteria_menu'}),
  );

  @override
  Future<void> cancelAdvice() =>
      _notifications.cancel(id: LocalAdviceScheduler.notificationId);
}
