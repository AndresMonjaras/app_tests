import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/notifications/data/notification_message_listeners.dart';

void main() {
  test(
    'atiende foreground, apertura y arranque terminado una sola vez',
    () async {
      final foreground = StreamController<String>.broadcast();
      final opened = StreamController<String>.broadcast();
      final foregroundReceived = <String>[];
      final openedReceived = <String>[];
      var initialReads = 0;
      final listeners = NotificationMessageListeners<String>(
        foregroundMessages: foreground.stream,
        openedMessages: opened.stream,
        initialMessage: () async {
          initialReads++;
          return 'terminated';
        },
        onForeground: (message) async => foregroundReceived.add(message),
        onOpened: (message) async => openedReceived.add(message),
      );
      addTearDown(() async {
        await listeners.dispose();
        await foreground.close();
        await opened.close();
      });

      await listeners.start();
      await listeners.start();
      foreground.add('foreground');
      opened.add('background-tap');
      await Future<void>.delayed(Duration.zero);

      expect(foregroundReceived, ['foreground']);
      expect(openedReceived, ['terminated', 'background-tap']);
      expect(initialReads, 1);
    },
  );

  test('no abre mensaje inicial cuando no existe', () async {
    final opened = <String>[];
    final listeners = NotificationMessageListeners<String>(
      foregroundMessages: const Stream<String>.empty(),
      openedMessages: const Stream<String>.empty(),
      initialMessage: () async => null,
      onForeground: (_) async {},
      onOpened: (message) async => opened.add(message),
    );
    addTearDown(listeners.dispose);

    await listeners.start();

    expect(opened, isEmpty);
  });
}
