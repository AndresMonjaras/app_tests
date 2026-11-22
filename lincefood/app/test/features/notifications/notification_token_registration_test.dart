import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/notifications/data/notification_token_registration.dart';

void main() {
  test('el hash SHA-256 es estable y no guarda el token como clave', () {
    const token = 'fcm-token-de-prueba';

    final firstHash = notificationTokenHash(token);

    expect(firstHash, notificationTokenHash(token));
    expect(firstHash, isNot(token));
    expect(firstHash, hasLength(32));
    expect(firstHash, matches(RegExp(r'^[a-f0-9]{32}$')));
  });

  test(
    'guarda el token al registrarlo y lo elimina al cerrar sesión',
    () async {
      final repository = _FakeTokenRepository();
      final refreshes = StreamController<String>.broadcast();
      final registration = NotificationTokenRegistration(
        repository: repository,
        requestPermission: () async => true,
        readToken: () async => 'fcm-token-de-prueba',
        tokenRefreshes: refreshes.stream,
        unsubscribeFromTopic: (_) async {},
      );
      addTearDown(() async {
        await registration.dispose();
        await refreshes.close();
      });

      expect(await registration.registerForUser('usuario-1'), isTrue);
      expect(repository.saved, [('usuario-1', 'fcm-token-de-prueba')]);

      await registration.signOut();

      expect(repository.deleted, [('usuario-1', 'fcm-token-de-prueba')]);
    },
  );

  test('reemplaza el token anterior cuando FCM lo renueva', () async {
    final repository = _FakeTokenRepository();
    final refreshes = StreamController<String>.broadcast();
    final registration = NotificationTokenRegistration(
      repository: repository,
      requestPermission: () async => true,
      readToken: () async => 'token-anterior',
      tokenRefreshes: refreshes.stream,
      unsubscribeFromTopic: (_) async {},
    );
    addTearDown(() async {
      await registration.dispose();
      await refreshes.close();
    });

    await registration.registerForUser('usuario-1');
    refreshes.add('token-nuevo');
    await Future<void>.delayed(Duration.zero);

    expect(repository.deleted, [('usuario-1', 'token-anterior')]);
    expect(repository.saved.last, ('usuario-1', 'token-nuevo'));
  });
}

class _FakeTokenRepository implements NotificationTokenRepository {
  final saved = <(String, String)>[];
  final deleted = <(String, String)>[];

  @override
  Future<void> save(String uid, String token) async {
    saved.add((uid, token));
  }

  @override
  Future<void> delete(String uid, String token) async {
    deleted.add((uid, token));
  }
}
