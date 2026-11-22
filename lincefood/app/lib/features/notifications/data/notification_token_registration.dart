import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/notification_topic_preferences.dart';

abstract interface class NotificationTokenRepository {
  Future<void> save(String uid, String token);

  Future<void> delete(String uid, String token);
}

class FirebaseNotificationTokenRepository
    implements NotificationTokenRepository {
  FirebaseNotificationTokenRepository(this._database);

  final FirebaseDatabase _database;

  @override
  Future<void> save(String uid, String token) {
    final tokenHash = notificationTokenHash(token);
    return _database.ref('notificationTokens/$uid/$tokenHash').set({
      'token': token,
      'platform': 'android',
      'updatedAt': ServerValue.timestamp,
    });
  }

  @override
  Future<void> delete(String uid, String token) {
    final tokenHash = notificationTokenHash(token);
    return _database.ref('notificationTokens/$uid/$tokenHash').remove();
  }
}

String notificationTokenHash(String token) =>
    sha256.convert(utf8.encode(token)).toString().substring(0, 32);

class NotificationTokenRegistration {
  NotificationTokenRegistration({
    required this._repository,
    required this._requestPermission,
    required this._readToken,
    required this._tokenRefreshes,
    required this._unsubscribeFromTopic,
  });

  final NotificationTokenRepository _repository;
  final Future<bool> Function() _requestPermission;
  final Future<String?> Function() _readToken;
  final Stream<String> _tokenRefreshes;
  final Future<void> Function(String topic) _unsubscribeFromTopic;

  StreamSubscription<String>? _refreshSubscription;
  Future<void> _operations = Future<void>.value();
  String? _uid;
  String? _token;

  Future<void> start() async {
    if (_refreshSubscription != null) return;
    _refreshSubscription = _tokenRefreshes.listen((token) {
      unawaited(
        _enqueue(() async {
          final uid = _uid;
          if (uid != null) await _replaceToken(uid, token);
        }).catchError((Object _) {}),
      );
    });
  }

  Future<bool> registerForUser(String uid) async {
    if (uid.isEmpty) return false;
    await start();
    return _enqueue(() => _registerForUser(uid));
  }

  Future<void> signOut() => _enqueue(_signOut);

  Future<void> dispose() async {
    await _refreshSubscription?.cancel();
    _refreshSubscription = null;
  }

  Future<bool> _registerForUser(String uid) async {
    if (_uid != uid) await _switchUser(uid);

    final isAllowed = await _requestPermission();
    if (!isAllowed || _uid != uid) return false;

    final token = await _readToken();
    if (token == null || token.isEmpty || _uid != uid) return false;

    await _replaceToken(uid, token);
    return _uid == uid && _token == token;
  }

  Future<void> _switchUser(String uid) async {
    final previousUid = _uid;
    final previousToken = _token;
    _uid = uid;
    _token = null;

    if (previousUid == null) return;
    try {
      if (previousToken != null) {
        await _repository.delete(previousUid, previousToken);
      }
    } finally {
      await _unsubscribeTopics();
    }
  }

  Future<void> _signOut() async {
    final previousUid = _uid;
    final previousToken = _token;
    _uid = null;
    _token = null;

    try {
      if (previousUid != null && previousToken != null) {
        await _repository.delete(previousUid, previousToken);
      }
    } finally {
      await _unsubscribeTopics();
    }
  }

  Future<void> _replaceToken(String uid, String token) async {
    if (_uid != uid || token.isEmpty) return;

    final previousToken = _token;
    if (previousToken != null && previousToken != token) {
      await _repository.delete(uid, previousToken);
    }
    await _repository.save(uid, token);
    if (_uid == uid) _token = token;
  }

  Future<void> _unsubscribeTopics() async {
    await Future.wait(
      NotificationTopic.values.map((topic) => _unsubscribeFromTopic(topic.key)),
      eagerError: false,
    );
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _operations = _operations.then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}

final notificationTokenRegistrationProvider =
    Provider<NotificationTokenRegistration>((ref) {
      final messaging = FirebaseMessaging.instance;
      final registration = NotificationTokenRegistration(
        repository: FirebaseNotificationTokenRepository(
          FirebaseDatabase.instance,
        ),
        requestPermission: () async {
          final settings = await messaging.requestPermission();
          return settings.authorizationStatus ==
                  AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;
        },
        // El contrato del proyecto requiere el token actual y su renovación.
        // ignore: deprecated_member_use
        readToken: () => messaging.getToken(),
        // ignore: deprecated_member_use
        tokenRefreshes: messaging.onTokenRefresh,
        unsubscribeFromTopic: messaging.unsubscribeFromTopic,
      );
      ref.onDispose(registration.dispose);
      return registration;
    });
