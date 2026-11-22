import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/notifications/data/notification_preferences_gateway.dart';
import 'package:lincefood_app/features/notifications/domain/notification_inbox_item.dart';
import 'package:lincefood_app/features/notifications/domain/notification_topic_preferences.dart';
import 'package:lincefood_app/features/notifications/presentation/notification_preferences_controller.dart';
import 'package:lincefood_app/features/notifications/presentation/notification_preferences_screen.dart';

void main() {
  testWidgets('muestra preferencias e historial en español', (tester) async {
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
        ],
        child: const MaterialApp(home: NotificationPreferencesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Menú de la cafetería'), findsOneWidget);
    expect(find.text('Ofertas'), findsOneWidget);
    expect(find.text('Avisos de la cafetería'), findsOneWidget);
    expect(find.text('Consejos de cafetería'), findsOneWidget);
    expect(find.text('Historial'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNWidgets(4));
  });
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
