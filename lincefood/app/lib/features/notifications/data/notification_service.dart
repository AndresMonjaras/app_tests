import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_router.dart';
import '../../../core/config/firebase_bootstrap_provider.dart';
import '../domain/cafeteria_tips.dart';
import '../domain/local_advice_frequency.dart';
import '../domain/notification_message_mapper.dart';
import '../domain/notification_topic_preferences.dart';
import 'local_advice_frequency_store.dart';
import 'local_advice_scheduler.dart';
import 'notification_message_listeners.dart';
import 'notification_preferences_gateway.dart';
import 'notification_token_registration.dart';

final notificationNavigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> lincefoodFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  // El sistema gestiona la notificación en segundo plano; aquí no se accede a la UI.
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService(
    FirebaseMessaging.instance,
    FirebaseAuth.instance,
    FlutterLocalNotificationsPlugin(),
    notificationNavigatorKey,
    ref.watch(notificationTokenRegistrationProvider),
    localAdviceFrequencyStore: ref.watch(localAdviceFrequencyStoreProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

abstract interface class LocalAdvicePreferenceHandler {
  Future<void> setLocalAdviceEnabled(bool enabled);

  Future<void> setLocalAdviceFrequency(
    LocalAdviceFrequency frequency, {
    required bool enabled,
  });
}

final localAdvicePreferenceHandlerProvider =
    Provider<LocalAdvicePreferenceHandler>(
      (ref) => ref.watch(notificationServiceProvider),
    );

final notificationStartupProvider = FutureProvider<void>((ref) async {
  final status = await ref.watch(firebaseBootstrapProvider.future);
  if (status == FirebaseBootstrapStatus.missing || Firebase.apps.isEmpty) {
    return;
  }

  await ref.read(notificationServiceProvider).start();
});

class NotificationService implements LocalAdvicePreferenceHandler {
  NotificationService(
    FirebaseMessaging messaging,
    FirebaseAuth authentication,
    FlutterLocalNotificationsPlugin localNotifications,
    GlobalKey<NavigatorState> navigatorKey,
    NotificationTokenRegistration tokenRegistration, {
    LocalAdviceScheduler? localAdviceScheduler,
    LocalAdviceFrequencyStore? localAdviceFrequencyStore,
  }) : _messaging = messaging,
       _authentication = authentication,
       _localNotifications = localNotifications,
       _navigatorKey = navigatorKey,
       _tokenRegistration = tokenRegistration,
       _localAdviceScheduler =
           localAdviceScheduler ??
           LocalAdviceScheduler(
             FlutterLocalAdviceNotificationClient(localNotifications),
           ),
       _localAdviceFrequencyStore =
           localAdviceFrequencyStore ??
           SharedPreferencesLocalAdviceFrequencyStore();

  static const _channelId = 'avisos_cafeteria';
  static const _channelName = 'Avisos de la cafetería';
  static const _channelDescription = 'Avisos de la cafetería Lincefood';

  final FirebaseMessaging _messaging;
  final FirebaseAuth _authentication;
  final FlutterLocalNotificationsPlugin _localNotifications;
  final GlobalKey<NavigatorState> _navigatorKey;
  final NotificationTokenRegistration _tokenRegistration;
  final LocalAdviceScheduler _localAdviceScheduler;
  final LocalAdviceFrequencyStore _localAdviceFrequencyStore;

  NotificationMessageListeners<RemoteMessage>? _messageListeners;
  StreamSubscription<User?>? _authSubscription;
  Future<void> _authQueue = Future<void>.value();
  Future<void> _localAdviceQueue = Future<void>.value();
  NotificationMessageMapper? _mapper;
  Future<void>? _startFuture;

  Future<void> start() => _startFuture ??= _startOnce();

  void dispose() {
    unawaited(_messageListeners?.dispose());
    unawaited(_authSubscription?.cancel());
  }

  @override
  Future<void> setLocalAdviceEnabled(bool enabled) async {
    await start();
    await _queueLocalAdviceUpdate(() async {
      if (!enabled) {
        await _localAdviceScheduler.cancel();
        return;
      }

      final androidNotifications = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      var canNotify = await androidNotifications?.areNotificationsEnabled();
      if (canNotify != true) {
        final settings = await _messaging.requestPermission();
        canNotify =
            settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
      }
      if (canNotify != true) {
        throw StateError(
          'Permite las notificaciones para activar los consejos.',
        );
      }
      await _scheduleNextLocalAdvice();
    });
  }

  @override
  Future<void> setLocalAdviceFrequency(
    LocalAdviceFrequency frequency, {
    required bool enabled,
  }) async {
    if (enabled) await start();
    await _queueLocalAdviceUpdate(() async {
      final previousFrequency = await _localAdviceFrequencyStore
          .readFrequency();
      if (frequency == previousFrequency) return;

      try {
        await _localAdviceFrequencyStore.writeFrequency(frequency);
        if (enabled) await _scheduleNextLocalAdvice();
      } catch (_) {
        try {
          await _localAdviceFrequencyStore.writeFrequency(previousFrequency);
        } catch (error, stack) {
          debugPrint('No se pudo restaurar la frecuencia: $error\n$stack');
        }
        rethrow;
      }
    });
  }

  Future<void> _queueLocalAdviceUpdate(Future<void> Function() update) {
    final result = _localAdviceQueue.then((_) => update());
    _localAdviceQueue = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<void> _scheduleNextLocalAdvice() async {
    final frequency = await _localAdviceFrequencyStore.readFrequency();
    final nextIndex = await _localAdviceFrequencyStore.readNextTipIndex();
    final index = nextIndex % cafeteriaTips.length;

    try {
      await _localAdviceFrequencyStore.writeNextTipIndex(
        (index + 1) % cafeteriaTips.length,
      );
      await _localAdviceScheduler.schedule(frequency, cafeteriaTips[index]);
    } catch (_) {
      try {
        await _localAdviceFrequencyStore.writeNextTipIndex(nextIndex);
      } catch (error, stack) {
        debugPrint(
          'No se pudo restaurar el índice del consejo: $error\n$stack',
        );
      }
      rethrow;
    }
  }

  Future<void> _startOnce() async {
    FirebaseMessaging.onBackgroundMessage(
      lincefoodFirebaseMessagingBackgroundHandler,
    );
    _mapper = await NotificationMessageMapper.loadSeed();
    await _initializeLocalNotifications();

    _messageListeners = NotificationMessageListeners<RemoteMessage>(
      foregroundMessages: FirebaseMessaging.onMessage,
      openedMessages: FirebaseMessaging.onMessageOpenedApp,
      initialMessage: _messaging.getInitialMessage,
      onForeground: _showForegroundMessage,
      onOpened: _openMessage,
    );
    await _messageListeners!.start();
    await _tokenRegistration.start();
    _authSubscription = _authentication.authStateChanges().listen(
      _queueTokenSync,
    );

    final localLaunch = await _localNotifications
        .getNotificationAppLaunchDetails();
    if (localLaunch?.didNotificationLaunchApp == true) {
      final localPayload = localLaunch?.notificationResponse?.payload;
      if (localPayload != null) _openLocalPayload(localPayload);
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _localNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null) _openLocalPayload(payload);
      },
    );

    final androidNotifications = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidNotifications?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      ),
    );
  }

  Future<void> _showForegroundMessage(RemoteMessage message) async {
    final content = _mapper?.mapPayload(message.data);
    if (content == null) {
      // Las campañas de la consola no traen "tipo"; se muestra su título y texto.
      await _showConsoleMessage(message);
      return;
    }

    await _localNotifications.show(
      id: message.messageId?.hashCode ?? content.key.hashCode,
      title: content.title,
      body: content.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          icon: 'ic_notification',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode({
        'tipo': content.key,
        if (content.orderId != null) 'orderId': content.orderId,
      }),
    );
  }

  Future<void> _showConsoleMessage(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title?.trim() ?? '';
    final body = notification?.body?.trim() ?? '';
    if (title.isEmpty && body.isEmpty) return;

    await _localNotifications.show(
      id: message.messageId?.hashCode ?? '$title$body'.hashCode,
      title: title.isEmpty ? 'Lincefood' : title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          icon: 'ic_notification',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  void _queueTokenSync(User? user) {
    _authQueue = _authQueue.then((_) async {
      if (user == null) {
        try {
          await _tokenRegistration.signOut();
        } catch (_) {
          // El cierre de sesión no depende del registro del token.
        }
        try {
          await _queueLocalAdviceUpdate(_localAdviceScheduler.cancel);
        } catch (_) {
          // La cancelación se reintenta al cambiar las preferencias.
        }
      } else {
        try {
          final registered = await _tokenRegistration.registerForUser(user.uid);
          if (registered) await _syncTopicSubscriptions(user.uid);
        } catch (_) {
          // La app puede seguir funcionando aunque falle el registro del token.
        }
        await _syncLocalAdvice(user.uid);
      }
    });
  }

  Future<void> _syncTopicSubscriptions(String uid) async {
    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('notificationPreferences/$uid')
          .get();
      if (_authentication.currentUser?.uid != uid) return;
      final preferences = NotificationTopicPreferences.fromMap(snapshot.value);
      await applyTopicSubscriptions(
        preferences: preferences,
        subscribe: (topic) async {
          if (_authentication.currentUser?.uid != uid) return;
          await _messaging.subscribeToTopic(topic);
        },
        unsubscribe: (topic) async {
          if (_authentication.currentUser?.uid != uid) return;
          await _messaging.unsubscribeFromTopic(topic);
        },
      );
    } catch (_) {
      // La sesión permanece disponible aunque no se puedan restaurar los topics.
    }
  }

  Future<void> _syncLocalAdvice(String uid) async {
    try {
      await _queueLocalAdviceUpdate(() async {
        if (_authentication.currentUser?.uid != uid) return;
        final snapshot = await FirebaseDatabase.instance
            .ref(
              'notificationPreferences/$uid/${NotificationTopicPreferences.localAdviceKey}',
            )
            .get();
        if (_authentication.currentUser?.uid != uid) return;
        if (snapshot.value == true) {
          await _scheduleNextLocalAdvice();
        } else {
          await _localAdviceScheduler.cancel();
        }
      });
    } catch (error, stack) {
      // La app sigue abierta, pero el fallo debe verse en el log del dispositivo.
      debugPrint(
        'No se pudo sincronizar el recordatorio local: $error\n$stack',
      );
    }
  }

  Future<void> _openMessage(RemoteMessage message) =>
      _openPayload(message.data);

  Future<void> _openPayload(Map<String, Object?> payload) async {
    final content = _mapper?.mapPayload(payload);
    if (content == null) return;

    final hasSession = await _hasValidSession();
    await WidgetsBinding.instance.endOfFrame;
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;

    final route = hasSession
        ? switch (content.target) {
            NotificationTarget.catalog => AppRouter.catalog,
            NotificationTarget.orders => AppRouter.orders,
            NotificationTarget.pickupQr =>
              content.orderId == null ? AppRouter.orders : AppRouter.pickupQr,
          }
        : AppRouter.auth;
    navigator.pushNamed(
      route,
      arguments: content.orderId == null ? null : {'orderId': content.orderId},
    );
  }

  void _openLocalPayload(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        _openPayload(Map<String, Object?>.from(decoded));
        return;
      }
    } on FormatException {
      // Versiones anteriores guardaban solo la clave del aviso.
    }
    _openPayload({'tipo': payload});
  }

  Future<bool> _hasValidSession() async {
    try {
      final user = await _authentication.authStateChanges().first;
      if (user == null) return false;
      await user.reload();
      return _authentication.currentUser?.uid == user.uid;
    } catch (_) {
      return false;
    }
  }
}
