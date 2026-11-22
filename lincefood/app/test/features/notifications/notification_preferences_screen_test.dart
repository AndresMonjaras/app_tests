import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/notifications/data/local_advice_frequency_store.dart';
import 'package:lincefood_app/features/notifications/data/notification_preferences_gateway.dart';
import 'package:lincefood_app/features/notifications/data/notification_service.dart';
import 'package:lincefood_app/features/notifications/domain/local_advice_frequency.dart';
import 'package:lincefood_app/features/notifications/domain/notification_inbox_item.dart';
import 'package:lincefood_app/features/notifications/domain/notification_topic_preferences.dart';
import 'package:lincefood_app/features/notifications/presentation/notification_preferences_controller.dart';
import 'package:lincefood_app/features/notifications/presentation/notification_preferences_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final selector = find.byType(SegmentedButton<LocalAdviceFrequency>);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('muestra preferencias e historial en español', (tester) async {
    await _openPreferences(tester);

    expect(find.text('Menú de la cafetería'), findsOneWidget);
    expect(find.text('Ofertas'), findsOneWidget);
    expect(find.text('Avisos de la cafetería'), findsOneWidget);
    expect(find.text('Historial'), findsOneWidget);
    expect(find.text('Consejos de la cafetería'), findsOneWidget);
    expect(find.text('Recordatorio local de consejos'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNWidgets(5));
    expect(find.text('Una vez al día'), findsOneWidget);
    expect(find.text('Cada hora'), findsOneWidget);
    final frequencySelector = tester
        .widget<SegmentedButton<LocalAdviceFrequency>>(selector);
    expect(frequencySelector.selected, {LocalAdviceFrequency.daily});
    expect(frequencySelector.onSelectionChanged, isNull);
  });

  testWidgets('permite cambiar la frecuencia con el recordatorio activo', (
    tester,
  ) async {
    final store = SharedPreferencesLocalAdviceFrequencyStore();
    await store.writeFrequency(LocalAdviceFrequency.hourly);
    final handler = _FakeAdviceHandler(store);
    await _openPreferences(tester, handler: handler);

    expect(
      tester.widget<SegmentedButton<LocalAdviceFrequency>>(selector).selected,
      {LocalAdviceFrequency.hourly},
    );
    final reminder = find.descendant(
      of: find.widgetWithText(SwitchListTile, 'Recordatorio local de consejos'),
      matching: find.byType(Switch),
    );
    await tester.ensureVisible(reminder);
    await tester.tap(reminder);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<SegmentedButton<LocalAdviceFrequency>>(selector)
          .onSelectionChanged,
      isNotNull,
    );
    final daily = find.text('Una vez al día');
    await tester.ensureVisible(daily);
    await tester.tap(daily);
    await tester.pumpAndSettle();

    expect(handler.frequencyChanges, [(LocalAdviceFrequency.daily, true)]);
    expect(await store.readFrequency(), LocalAdviceFrequency.daily);
    expect(
      tester.widget<SegmentedButton<LocalAdviceFrequency>>(selector).selected,
      {LocalAdviceFrequency.daily},
    );

    await tester.ensureVisible(reminder);
    await tester.tap(reminder);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<SegmentedButton<LocalAdviceFrequency>>(selector)
          .onSelectionChanged,
      isNull,
    );
  });

  testWidgets('espera la frecuencia guardada antes de marcar una opción', (
    tester,
  ) async {
    final frequency = Completer<LocalAdviceFrequency>();
    await _openPreferences(tester, initialFrequency: frequency.future);

    expect(
      tester.widget<SegmentedButton<LocalAdviceFrequency>>(selector).selected,
      isEmpty,
    );

    frequency.complete(LocalAdviceFrequency.hourly);
    await tester.pumpAndSettle();

    expect(
      tester.widget<SegmentedButton<LocalAdviceFrequency>>(selector).selected,
      {LocalAdviceFrequency.hourly},
    );
  });
}

Future<void> _openPreferences(
  WidgetTester tester, {
  _FakeAdviceHandler? handler,
  Future<LocalAdviceFrequency>? initialFrequency,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        notificationUserIdProvider.overrideWith((ref) => 'usuario-1'),
        notificationPreferencesGatewayProvider.overrideWithValue(
          _FakeGateway(),
        ),
        notificationInboxProvider.overrideWith(
          (ref) => Stream.value(const <NotificationInboxItem>[]),
        ),
        if (handler != null)
          localAdvicePreferenceHandlerProvider.overrideWithValue(handler),
        if (initialFrequency != null)
          localAdviceFrequencyProvider.overrideWith((ref) => initialFrequency),
      ],
      child: const MaterialApp(home: NotificationPreferencesScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeAdviceHandler implements LocalAdvicePreferenceHandler {
  _FakeAdviceHandler(this.store);

  final LocalAdviceFrequencyStore store;
  final frequencyChanges = <(LocalAdviceFrequency, bool)>[];

  @override
  Future<void> setLocalAdviceEnabled(bool enabled) async {}

  @override
  Future<void> setLocalAdviceFrequency(
    LocalAdviceFrequency frequency, {
    required bool enabled,
  }) async {
    frequencyChanges.add((frequency, enabled));
    await store.writeFrequency(frequency);
  }
}

class _FakeGateway implements NotificationPreferencesGateway {
  @override
  Future<NotificationTopicPreferences> load(String uid) async =>
      const NotificationTopicPreferences();

  @override
  Future<void> save(
    String uid,
    NotificationTopicPreferences preferences,
  ) async {}

  @override
  Future<void> subscribe(String uid, NotificationTopic topic) async {}

  @override
  Future<void> unsubscribe(NotificationTopic topic) async {}
}
