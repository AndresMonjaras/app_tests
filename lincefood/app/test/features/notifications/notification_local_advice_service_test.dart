import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/notifications/data/local_advice_frequency_store.dart';
import 'package:lincefood_app/features/notifications/data/local_advice_scheduler.dart';
import 'package:lincefood_app/features/notifications/data/notification_service.dart';
import 'package:lincefood_app/features/notifications/data/notification_token_registration.dart';
import 'package:lincefood_app/features/notifications/domain/cafeteria_tips.dart';
import 'package:lincefood_app/features/notifications/domain/local_advice_frequency.dart';

void main() {
  late _FakeAdviceStore store;
  late _FakeAdviceNotifications notifications;
  late NotificationService service;

  setUp(() {
    store = _FakeAdviceStore();
    notifications = _FakeAdviceNotifications();
    service = _TestNotificationService(store, notifications);
  });

  test(
    'al activar usa la frecuencia guardada y recorre todos los consejos',
    () async {
      store.frequency = LocalAdviceFrequency.hourly;

      await service.setLocalAdviceEnabled(true);
      for (var index = 1; index <= cafeteriaTips.length; index++) {
        await service.setLocalAdviceEnabled(false);
        service = _TestNotificationService(store, notifications);
        await service.setLocalAdviceEnabled(true);
      }

      expect(notifications.scheduled.map((entry) => entry.$1), [
        for (var index = 0; index <= cafeteriaTips.length; index++)
          LocalAdviceFrequency.hourly,
      ]);
      expect(notifications.scheduled.map((entry) => entry.$2), [
        ...cafeteriaTips,
        cafeteriaTips.first,
      ]);
      expect(store.nextTipIndex, 1);
    },
  );

  test(
    'cambiar la frecuencia con el recordatorio activo usa el siguiente consejo',
    () async {
      await service.setLocalAdviceEnabled(true);

      await service.setLocalAdviceFrequency(
        LocalAdviceFrequency.hourly,
        enabled: true,
      );

      expect(store.frequency, LocalAdviceFrequency.hourly);
      expect(notifications.scheduled, [
        (LocalAdviceFrequency.daily, cafeteriaTips[0]),
        (LocalAdviceFrequency.hourly, cafeteriaTips[1]),
      ]);
      expect(store.nextTipIndex, 2);
    },
  );

  test(
    'cambiar la frecuencia con el recordatorio apagado solo la guarda',
    () async {
      await service.setLocalAdviceFrequency(
        LocalAdviceFrequency.hourly,
        enabled: false,
      );

      expect(store.frequency, LocalAdviceFrequency.hourly);
      expect(notifications.scheduled, isEmpty);
      expect(store.nextTipIndex, 0);
    },
  );

  test(
    'un cambio de frecuencia fallido conserva la programación anterior',
    () async {
      await service.setLocalAdviceEnabled(true);
      notifications.failScheduling = true;

      await expectLater(
        service.setLocalAdviceFrequency(
          LocalAdviceFrequency.hourly,
          enabled: true,
        ),
        throwsStateError,
      );
      expect(store.frequency, LocalAdviceFrequency.daily);
      expect(store.nextTipIndex, 1);
      expect(notifications.scheduled.single, (
        LocalAdviceFrequency.daily,
        cafeteriaTips.first,
      ));

      notifications.failScheduling = false;
      await service.setLocalAdviceFrequency(
        LocalAdviceFrequency.hourly,
        enabled: true,
      );
      expect(notifications.scheduled.last, (
        LocalAdviceFrequency.hourly,
        cafeteriaTips[1],
      ));
      expect(store.nextTipIndex, 2);
    },
  );

  test('si falla el guardado del índice se conserva el aviso y el consejo pendiente', () async {
    await service.setLocalAdviceEnabled(true);
    store.failNextIndexWrite = true;

    await expectLater(
      service.setLocalAdviceFrequency(
        LocalAdviceFrequency.hourly,
        enabled: true,
      ),
      throwsStateError,
    );

    expect(store.frequency, LocalAdviceFrequency.daily);
    expect(store.nextTipIndex, 1);
    expect(notifications.scheduled, [
      (LocalAdviceFrequency.daily, cafeteriaTips.first),
    ]);

    await service.setLocalAdviceFrequency(
      LocalAdviceFrequency.hourly,
      enabled: true,
    );

    expect(store.frequency, LocalAdviceFrequency.hourly);
    expect(store.nextTipIndex, 2);
    expect(notifications.scheduled.last, (
      LocalAdviceFrequency.hourly,
      cafeteriaTips[1],
    ));
  });
}

class _TestNotificationService extends NotificationService {
  _TestNotificationService(
    LocalAdviceFrequencyStore store,
    LocalAdviceNotificationClient notifications,
  ) : super(
        _AuthorizedMessaging(),
        _UnusedAuthentication(),
        _LocalNotificationsWithoutAndroid(),
        GlobalKey<NavigatorState>(),
        _UnusedTokenRegistration(),
        localAdviceScheduler: LocalAdviceScheduler(notifications),
        localAdviceFrequencyStore: store,
      );

  @override
  Future<void> start() async {}
}

class _UnusedAuthentication extends Fake implements FirebaseAuth {}

class _UnusedTokenRegistration extends Fake
    implements NotificationTokenRegistration {}

class _AuthorizedMessaging extends Fake implements FirebaseMessaging {
  @override
  Future<NotificationSettings> requestPermission({
    bool alert = true,
    bool announcement = false,
    bool badge = true,
    bool carPlay = false,
    bool criticalAlert = false,
    bool provisional = false,
    bool sound = true,
    bool providesAppNotificationSettings = false,
  }) async => _AuthorizedSettings();
}

class _AuthorizedSettings extends Fake implements NotificationSettings {
  @override
  AuthorizationStatus get authorizationStatus => AuthorizationStatus.authorized;
}

class _LocalNotificationsWithoutAndroid extends Fake
    implements FlutterLocalNotificationsPlugin {
  @override
  T? resolvePlatformSpecificImplementation<
    T extends FlutterLocalNotificationsPlatform
  >() => null;
}

class _FakeAdviceStore implements LocalAdviceFrequencyStore {
  LocalAdviceFrequency frequency = LocalAdviceFrequency.daily;
  int nextTipIndex = 0;
  bool failNextIndexWrite = false;

  @override
  Future<LocalAdviceFrequency> readFrequency() async => frequency;

  @override
  Future<void> writeFrequency(LocalAdviceFrequency frequency) async {
    this.frequency = frequency;
  }

  @override
  Future<int> readNextTipIndex() async => nextTipIndex;

  @override
  Future<void> writeNextTipIndex(int index) async {
    nextTipIndex = index;
    if (failNextIndexWrite) {
      failNextIndexWrite = false;
      throw StateError('No se pudo guardar el siguiente consejo.');
    }
  }
}

class _FakeAdviceNotifications implements LocalAdviceNotificationClient {
  final scheduled = <(LocalAdviceFrequency, CafeteriaTip)>[];
  bool failScheduling = false;

  @override
  Future<void> schedule(
    LocalAdviceFrequency frequency,
    CafeteriaTip tip,
  ) async {
    if (failScheduling) throw StateError('No se pudo programar el consejo.');
    scheduled.add((frequency, tip));
  }

  @override
  Future<void> cancelAdvice() async {}
}
