import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/notifications/data/notification_preferences_gateway.dart';
import 'package:lincefood_app/features/notifications/domain/notification_topic_preferences.dart';

void main() {
  test('serializa los topics y el opt-in de consejos locales', () {
    const initial = NotificationTopicPreferences();
    final updated = initial.withTopic(NotificationTopic.offers, true);
    final withAdvice = updated.copyWith(localAdvice: true);

    expect(updated.isEnabled(NotificationTopic.offers), isTrue);
    expect(updated.isEnabled(NotificationTopic.menu), isFalse);
    expect(withAdvice.localAdvice, isTrue);
    expect(
      NotificationTopicPreferences.fromMap(withAdvice.toMap()).toMap(),
      withAdvice.toMap(),
    );
  });

  test('suscribe al topic y guarda la preferencia', () async {
    final gateway = _FakeGateway();
    const initial = NotificationTopicPreferences();

    final updated = await applyTopicPreference(
      gateway: gateway,
      uid: 'usuario-1',
      current: initial,
      topic: NotificationTopic.menu,
      enabled: true,
    );

    expect(gateway.subscribed, [NotificationTopic.menu]);
    expect(gateway.savedUid, 'usuario-1');
    expect(gateway.savedPreferences?.menu, isTrue);
    expect(updated.menu, isTrue);
  });

  test('revierte la suscripción si no se puede guardar', () async {
    final gateway = _FakeGateway(failOnSave: true);

    await expectLater(
      applyTopicPreference(
        gateway: gateway,
        uid: 'usuario-1',
        current: const NotificationTopicPreferences(),
        topic: NotificationTopic.announcements,
        enabled: true,
      ),
      throwsA(isA<StateError>()),
    );

    expect(gateway.subscribed, [NotificationTopic.announcements]);
    expect(gateway.unsubscribed, [NotificationTopic.announcements]);
  });

  test('un permiso denegado mantiene desactivado el tema', () async {
    final gateway = _FakeGateway(permissionGranted: false);
    const initial = NotificationTopicPreferences();

    await expectLater(
      applyTopicPreference(
        gateway: gateway,
        uid: 'usuario-1',
        current: initial,
        topic: NotificationTopic.menu,
        enabled: true,
      ),
      throwsA(isA<StateError>()),
    );

    expect(initial.menu, isFalse);
    expect(gateway.savedPreferences, isNull);
    expect(gateway.subscribed, isEmpty);
  });

  test('reaplica solo los topics opt-in al restaurar la sesión', () async {
    final subscribed = <String>[];
    final unsubscribed = <String>[];

    await applyTopicSubscriptions(
      preferences: const NotificationTopicPreferences(
        menu: true,
        announcements: true,
      ),
      subscribe: (topic) async => subscribed.add(topic),
      unsubscribe: (topic) async => unsubscribed.add(topic),
    );

    expect(subscribed, ['cafeteria_menu', 'cafeteria_avisos']);
    expect(unsubscribed, ['cafeteria_ofertas']);
  });
}

class _FakeGateway implements NotificationPreferencesGateway {
  _FakeGateway({this.failOnSave = false, this.permissionGranted = true});

  final bool failOnSave;
  final bool permissionGranted;
  final subscribed = <NotificationTopic>[];
  final unsubscribed = <NotificationTopic>[];
  String? savedUid;
  NotificationTopicPreferences? savedPreferences;

  @override
  Future<NotificationTopicPreferences> load(String uid) async =>
      const NotificationTopicPreferences();

  @override
  Future<void> save(
    String uid,
    NotificationTopicPreferences preferences,
  ) async {
    if (failOnSave) throw StateError('fallo');
    savedUid = uid;
    savedPreferences = preferences;
  }

  @override
  Future<void> subscribe(String uid, NotificationTopic topic) async {
    if (!permissionGranted) throw StateError('permiso denegado');
    subscribed.add(topic);
  }

  @override
  Future<void> unsubscribe(NotificationTopic topic) async {
    unsubscribed.add(topic);
  }
}
