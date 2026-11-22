import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/notifications/data/local_advice_scheduler.dart';
import 'package:lincefood_app/features/notifications/domain/cafeteria_tips.dart';
import 'package:lincefood_app/features/notifications/domain/local_advice_frequency.dart';

void main() {
  const intervals = {
    LocalAdviceFrequency.daily: RepeatInterval.daily,
    LocalAdviceFrequency.hourly: RepeatInterval.hourly,
  };

  for (final entry in intervals.entries) {
    test('programa ${entry.key.label} y puede cancelar el consejo', () async {
      final notifications = _FakeNotificationsPlugin();
      final scheduler = LocalAdviceScheduler(
        FlutterLocalAdviceNotificationClient(notifications),
      );
      final tip = cafeteriaTips.first;

      await scheduler.schedule(entry.key, tip);
      await scheduler.cancel();

      expect(notifications.repeatInterval, entry.value);
      expect(notifications.scheduledId, 48120);
      expect(notifications.body, tip.text);
      expect(notifications.androidDetails?.channelId, 'avisos_cafeteria');
      expect(notifications.androidDetails?.icon, 'ic_notification');
      expect(notifications.cancelledId, notifications.scheduledId);
    });
  }
}

class _FakeNotificationsPlugin extends Fake
    implements FlutterLocalNotificationsPlugin {
  int? scheduledId;
  int? cancelledId;
  RepeatInterval? repeatInterval;
  String? body;
  AndroidNotificationDetails? androidDetails;

  @override
  Future<void> periodicallyShow({
    required int id,
    required RepeatInterval repeatInterval,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    String? title,
    String? body,
    String? payload,
  }) async {
    scheduledId = id;
    this.repeatInterval = repeatInterval;
    this.body = body;
    androidDetails = notificationDetails.android;
  }

  @override
  Future<void> cancel({required int id, String? tag}) async {
    cancelledId = id;
  }
}
