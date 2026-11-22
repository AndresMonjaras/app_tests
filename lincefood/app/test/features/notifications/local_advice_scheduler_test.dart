import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/notifications/data/local_advice_scheduler.dart';

void main() {
  test('programa un consejo por hora y puede cancelarlo', () async {
    final notifications = _FakeLocalAdviceNotifications();
    final scheduler = LocalAdviceScheduler(notifications);

    await scheduler.scheduleDailyAdvice();
    await scheduler.cancel();

    expect(notifications.scheduled, isTrue);
    expect(notifications.cancelled, isTrue);
  });
}

class _FakeLocalAdviceNotifications implements LocalAdviceNotificationClient {
  bool scheduled = false;
  bool cancelled = false;

  @override
  Future<void> scheduleDailyAdvice() async {
    scheduled = true;
  }

  @override
  Future<void> cancelAdvice() async {
    cancelled = true;
  }
}
