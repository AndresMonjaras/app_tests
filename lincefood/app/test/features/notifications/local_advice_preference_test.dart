import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/notifications/data/notification_preferences_gateway.dart';
import 'package:lincefood_app/features/notifications/data/notification_service.dart';
import 'package:lincefood_app/features/notifications/domain/local_advice_frequency.dart';
import 'package:lincefood_app/features/notifications/domain/notification_topic_preferences.dart';
import 'package:lincefood_app/features/notifications/presentation/notification_preferences_controller.dart';

void main() {
  test('guarda el opt-in y programa el consejo local', () async {
    final gateway = _FakeGateway();
    final advice = _FakeAdviceHandler();
    final container = ProviderContainer(
      overrides: [
        notificationUserIdProvider.overrideWith((ref) => 'usuario-1'),
        notificationPreferencesGatewayProvider.overrideWithValue(gateway),
        localAdvicePreferenceHandlerProvider.overrideWithValue(advice),
      ],
    );
    addTearDown(container.dispose);
    await container.read(notificationPreferencesControllerProvider.future);

    await container
        .read(notificationPreferencesControllerProvider.notifier)
        .setLocalAdvice(true);

    expect(gateway.saved.single.localAdvice, isTrue);
    expect(advice.changes, [true]);
    expect(
      container
          .read(notificationPreferencesControllerProvider)
          .requireValue
          .preferences
          .localAdvice,
      isTrue,
    );
  });

  test('revierte el opt-in si no se puede programar el aviso', () async {
    final gateway = _FakeGateway();
    final advice = _FakeAdviceHandler(fail: true);
    final container = ProviderContainer(
      overrides: [
        notificationUserIdProvider.overrideWith((ref) => 'usuario-1'),
        notificationPreferencesGatewayProvider.overrideWithValue(gateway),
        localAdvicePreferenceHandlerProvider.overrideWithValue(advice),
      ],
    );
    addTearDown(container.dispose);
    await container.read(notificationPreferencesControllerProvider.future);

    await container
        .read(notificationPreferencesControllerProvider.notifier)
        .setLocalAdvice(true);

    expect(gateway.saved.map((preferences) => preferences.localAdvice), [
      true,
      false,
    ]);
    expect(
      container
          .read(notificationPreferencesControllerProvider)
          .requireValue
          .preferences
          .localAdvice,
      isFalse,
    );
  });

  test('muestra el error si no se puede cambiar la frecuencia', () async {
    final gateway = _FakeGateway();
    final advice = _FakeAdviceHandler(fail: true);
    final container = ProviderContainer(
      overrides: [
        notificationUserIdProvider.overrideWith((ref) => 'usuario-1'),
        notificationPreferencesGatewayProvider.overrideWithValue(gateway),
        localAdvicePreferenceHandlerProvider.overrideWithValue(advice),
      ],
    );
    addTearDown(container.dispose);
    await container.read(notificationPreferencesControllerProvider.future);

    await container
        .read(notificationPreferencesControllerProvider.notifier)
        .setLocalAdviceFrequency(LocalAdviceFrequency.hourly);

    expect(gateway.saved, isEmpty);
    expect(advice.frequencyChanges, [(LocalAdviceFrequency.hourly, false)]);
    final state = container
        .read(notificationPreferencesControllerProvider)
        .requireValue;
    expect(state.savingTopic, isNull);
    expect(
      state.errorMessage,
      'No se pudo cambiar la frecuencia. Inténtalo de nuevo.',
    );
  });
}

class _FakeGateway implements NotificationPreferencesGateway {
  final saved = <NotificationTopicPreferences>[];

  @override
  Future<NotificationTopicPreferences> load(String uid) async =>
      const NotificationTopicPreferences();

  @override
  Future<void> save(
    String uid,
    NotificationTopicPreferences preferences,
  ) async {
    saved.add(preferences);
  }

  @override
  Future<void> subscribe(String uid, NotificationTopic topic) async {}

  @override
  Future<void> unsubscribe(NotificationTopic topic) async {}
}

class _FakeAdviceHandler implements LocalAdvicePreferenceHandler {
  _FakeAdviceHandler({this.fail = false});

  final bool fail;
  final changes = <bool>[];
  final frequencyChanges = <(LocalAdviceFrequency, bool)>[];

  @override
  Future<void> setLocalAdviceEnabled(bool enabled) async {
    changes.add(enabled);
    if (fail) throw StateError('No se pudo programar.');
  }

  @override
  Future<void> setLocalAdviceFrequency(
    LocalAdviceFrequency frequency, {
    required bool enabled,
  }) async {
    frequencyChanges.add((frequency, enabled));
    if (fail) throw StateError('No se pudo programar.');
  }
}
