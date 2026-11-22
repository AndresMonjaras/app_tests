import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../navigation/app_navigation_keys.dart';

@pragma('vm:entry-point')
Future<void> lincefoodFirebaseBackgroundHandler(RemoteMessage message) async {
  // La notificación visible la administra Android. Los datos del pedido se
  // consultan desde RTDB al abrir la aplicación y nunca se confían al payload.
}

class FirebaseNotificationService {
  FirebaseNotificationService({
    required this.messaging,
    required this.database,
  });

  static const Map<String, String> topics = {
    'cafeteria_menu': 'Novedades del menú',
    'cafeteria_ofertas': 'Promociones generales',
    'cafeteria_avisos': 'Horarios y avisos generales',
  };

  final FirebaseMessaging messaging;
  final FirebaseDatabase database;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<String>? _registrationSubscription;
  String? _activeUid;
  String? _activeInstallationId;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    FirebaseMessaging.onBackgroundMessage(lincefoodFirebaseBackgroundHandler);
    _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
      final notice = message.notification;
      final title = notice?.title ?? 'Aviso de Lincefood';
      final body = notice?.body;
      appScaffoldMessengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(body == null ? title : '$title: $body')),
        );
    });
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _openOrders,
    );
    _registrationSubscription = messaging.onRegistered.listen((
      installationId,
    ) async {
      final uid = _activeUid;
      if (uid != null) {
        await _saveDeviceRegistration(uid, installationId);
      }
    });
    try {
      if (await messaging.getInitialMessage() != null) _openOrders(null);
    } catch (_) {
      // La navegación normal consulta el pedido aunque no llegue el push.
    }
  }

  void _openOrders(RemoteMessage? message) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !user.emailVerified) return;
    appNavigatorKey.currentState?.pushNamed('/orders');
  }

  Future<Map<String, bool>> loadPreferences(String uid) async {
    await _switchIdentity(uid);
    final snapshot = await database.ref('notificationPreferences/$uid').get();
    final raw = snapshot.value;
    final stored = raw is Map
        ? raw.map((key, value) => MapEntry('$key', value == true))
        : <String, bool>{};
    final preferences = {
      for (final topic in topics.keys) topic: stored[topic] ?? false,
    };
    for (final entry in preferences.entries) {
      if (entry.value) {
        await messaging.subscribeToTopic(entry.key);
      } else {
        await messaging.unsubscribeFromTopic(entry.key);
      }
    }
    if (preferences.values.any((enabled) => enabled)) {
      await messaging.register();
    }
    return preferences;
  }

  Future<bool> changePreference({
    required String uid,
    required String topic,
    required bool enabled,
  }) async {
    if (!topics.containsKey(topic)) {
      throw ArgumentError.value(topic, 'topic', 'Canal no permitido.');
    }
    await _switchIdentity(uid);
    if (enabled) {
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final allowed =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!allowed) return false;
      await messaging.register();
      await messaging.subscribeToTopic(topic);
    } else {
      await messaging.unsubscribeFromTopic(topic);
    }

    try {
      await database.ref('notificationPreferences/$uid/$topic').set(enabled);
      return true;
    } catch (_) {
      if (enabled) {
        await messaging.unsubscribeFromTopic(topic);
      } else {
        await messaging.subscribeToTopic(topic);
      }
      rethrow;
    }
  }

  Future<void> _switchIdentity(String uid) async {
    if (_activeUid != null && _activeUid != uid) {
      await clearDeviceSubscriptions();
    }
    _activeUid = uid;
  }

  Future<void> _saveDeviceRegistration(
    String uid,
    String installationId,
  ) async {
    try {
      if (installationId.isEmpty || _activeUid != uid) return;
      _activeInstallationId = installationId;
      final deviceId = base64Url
          .encode(utf8.encode(installationId))
          .replaceAll('=', '');
      await database.ref('deviceRegistrations/$uid/$deviceId').set({
        'registeredAt': ServerValue.timestamp,
        'installationId': installationId,
      });
    } catch (_) {
      // FCM puede no estar disponible en emuladores de Auth/RTDB.
    }
  }

  Future<void> clearDeviceSubscriptions() async {
    for (final topic in topics.keys) {
      try {
        await messaging.unsubscribeFromTopic(topic);
      } catch (_) {
        // El cierre de sesión debe continuar aunque FCM no responda.
      }
    }
    final oldUid = _activeUid;
    final installationId = _activeInstallationId;
    if (oldUid != null && installationId != null) {
      try {
        final deviceId = base64Url
            .encode(utf8.encode(installationId))
            .replaceAll('=', '');
        await database.ref('deviceRegistrations/$oldUid/$deviceId').remove();
      } catch (_) {
        // La limpieza es best effort cuando el dispositivo está sin red.
      }
    }
    _activeUid = null;
    _activeInstallationId = null;
  }

  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _registrationSubscription?.cancel();
  }
}
