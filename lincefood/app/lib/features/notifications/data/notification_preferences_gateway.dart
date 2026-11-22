import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'notification_token_registration.dart';
import '../domain/notification_topic_preferences.dart';

abstract interface class NotificationPreferencesGateway {
  Future<NotificationTopicPreferences> load(String uid);

  Future<void> save(String uid, NotificationTopicPreferences preferences);

  Future<void> subscribe(String uid, NotificationTopic topic);

  Future<void> unsubscribe(NotificationTopic topic);
}

Future<void> applyTopicSubscriptions({
  required NotificationTopicPreferences preferences,
  required Future<void> Function(String topic) subscribe,
  required Future<void> Function(String topic) unsubscribe,
}) async {
  for (final topic in NotificationTopic.values) {
    if (preferences.isEnabled(topic)) {
      await subscribe(topic.key);
    } else {
      await unsubscribe(topic.key);
    }
  }
}

class FirebaseNotificationPreferencesGateway
    implements NotificationPreferencesGateway {
  FirebaseNotificationPreferencesGateway(
    this._database,
    this._messaging,
    this._authentication,
    this._tokenRegistration,
  );

  final FirebaseDatabase _database;
  final FirebaseMessaging _messaging;
  final FirebaseAuth _authentication;
  final NotificationTokenRegistration _tokenRegistration;

  @override
  Future<NotificationTopicPreferences> load(String uid) async {
    _requireCurrentUser(uid);
    final snapshot = await _preferencesReference(uid).get();
    _requireCurrentUser(uid);
    return NotificationTopicPreferences.fromMap(snapshot.value);
  }

  @override
  Future<void> save(String uid, NotificationTopicPreferences preferences) {
    _requireCurrentUser(uid);
    return _preferencesReference(uid).set(preferences.toMap());
  }

  @override
  Future<void> subscribe(String uid, NotificationTopic topic) async {
    _requireCurrentUser(uid);
    final isRegistered = await _tokenRegistration.registerForUser(uid);
    if (!isRegistered) {
      throw StateError('El permiso para notificaciones no está habilitado.');
    }
    _requireCurrentUser(uid);
    await _messaging.subscribeToTopic(topic.key);
  }

  @override
  Future<void> unsubscribe(NotificationTopic topic) =>
      _unsubscribeFromTopic(topic.key);

  Future<void> _unsubscribeFromTopic(String topic) =>
      _messaging.unsubscribeFromTopic(topic);

  DatabaseReference _preferencesReference(String uid) =>
      _database.ref('notificationPreferences/$uid');

  void _requireCurrentUser(String uid) {
    if (_authentication.currentUser?.uid != uid) {
      throw StateError('La sesión cambió. Inicia sesión e inténtalo de nuevo.');
    }
  }
}

Future<NotificationTopicPreferences> applyTopicPreference({
  required NotificationPreferencesGateway gateway,
  required String uid,
  required NotificationTopicPreferences current,
  required NotificationTopic topic,
  required bool enabled,
}) async {
  if (current.isEnabled(topic) == enabled) return current;

  final updated = current.withTopic(topic, enabled);
  var subscriptionChanged = false;
  try {
    if (enabled) {
      await gateway.subscribe(uid, topic);
    } else {
      await gateway.unsubscribe(topic);
    }
    subscriptionChanged = true;
    await gateway.save(uid, updated);
    return updated;
  } catch (_) {
    if (subscriptionChanged) {
      try {
        if (current.isEnabled(topic)) {
          await gateway.subscribe(uid, topic);
        } else {
          await gateway.unsubscribe(topic);
        }
      } catch (_) {
        // La pantalla conserva el estado anterior y permite volver a intentarlo.
      }
    }
    throw StateError('No se pudo guardar la preferencia de notificaciones.');
  }
}
