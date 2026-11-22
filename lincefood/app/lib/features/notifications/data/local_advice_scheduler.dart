import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../domain/cafeteria_tips.dart';
import '../domain/local_advice_frequency.dart';

class LocalAdviceScheduler {
  LocalAdviceScheduler(this._client);

  static const notificationId = 48120;

  final LocalAdviceNotificationClient _client;

  Future<void> schedule(LocalAdviceFrequency frequency, CafeteriaTip tip) =>
      _client.schedule(frequency, tip);

  Future<void> cancel() => _client.cancelAdvice();
}

abstract interface class LocalAdviceNotificationClient {
  Future<void> schedule(LocalAdviceFrequency frequency, CafeteriaTip tip);

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
  Future<void> schedule(LocalAdviceFrequency frequency, CafeteriaTip tip) {
    final repeatInterval = switch (frequency) {
      LocalAdviceFrequency.daily => RepeatInterval.daily,
      LocalAdviceFrequency.hourly => RepeatInterval.hourly,
    };
    // periodicallyShow repite el mismo texto hasta la siguiente programación.
    return _notifications.periodicallyShow(
      id: LocalAdviceScheduler.notificationId,
      repeatInterval: repeatInterval,
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
      body: tip.text,
      payload: jsonEncode({'type': 'cafeteria_menu'}),
    );
  }

  @override
  Future<void> cancelAdvice() =>
      _notifications.cancel(id: LocalAdviceScheduler.notificationId);
}
