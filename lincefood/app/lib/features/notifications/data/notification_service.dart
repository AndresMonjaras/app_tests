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
import 'local_advice_scheduler.dart';
import '../domain/notification_message_mapper.dart';
import '../domain/notification_topic_preferences.dart';
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
  );
  ref.onDispose(service.dispose);
  return service;
});

abstract interface class LocalAdvicePreferenceHandler {
  Future<void> setLocalAdviceEnabled(bool enabled);
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
  }) : _messaging = messaging,
       _authentication = authentication,
       _localNotifications = localNotifications,
       _navigatorKey = navigatorKey,
       _tokenRegistration = tokenRegistration,
       _localAdviceScheduler =
           localAdviceScheduler ??
           LocalAdviceScheduler(
             FlutterLocalAdviceNotificationClient(localNotifications),
           );

  static const _channelId = 'avisos_cafeteria';
  static const _channelName = 'Avisos de la cafetería';
  static const _channelDescription = 'Avisos de la cafetería Lincefood';

  final FirebaseMessaging _messaging;
  final FirebaseAuth _authentication;
  final FlutterLocalNotificationsPlugin _localNotifications;
  final GlobalKey<NavigatorState> _navigatorKey;
  final NotificationTokenRegistration _tokenRegistration;
  final LocalAdviceScheduler _localAdviceScheduler;

  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<User?>? _authSubscription;
  Future<void> _authQueue = Future<void>.value();
  NotificationMessageMapper? _mapper;
  Future<void>? _startFuture;

  Future<void> start() => _startFuture ??= _startOnce();

  void dispose() {
    unawaited(_foregroundSubscription?.cancel());
    unawaited(_openedSubscription?.cancel());
    unawaited(_authSubscription?.cancel());
  }

  @override
  Future<void> setLocalAdviceEnabled(bool enabled) async {
    await start();
    if (enabled) {
      final settings = await _messaging.requestPermission();
      final canNotify =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!canNotify) {
        throw StateError(
          'Permite las notificaciones para activar los consejos.',
        );
      }
      await _localAdviceScheduler.scheduleHourlyAdvice();
    } else {
      await _localAdviceScheduler.cancel();
    }
  }

  Future<void> _startOnce() async {
    FirebaseMessaging.onBackgroundMessage(
      lincefoodFirebaseMessagingBackgroundHandler,
    );
    _mapper = await NotificationMessageMapper.loadSeed();
    await _initializeLocalNotifications();

    _foregroundSubscription = FirebaseMessaging.onMessage.listen(
      _showForegroundMessage,
    );
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _openMessage,
    );
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

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) await _openMessage(initialMessage);
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
    if (content == null) return;

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

  void _queueTokenSync(User? user) {
    _authQueue = _authQueue.then((_) async {
      if (user == null) {
        try {
          await _tokenRegistration.signOut();
        } catch (_) {
          // El cierre de sesión no depende del registro del token.
        }
        try {
          await _localAdviceScheduler.cancel();
        } catch (_) {
          // La cancelación se reintenta al cambiar las preferencias.
        }
      } else {
        try {
          await _tokenRegistration.registerForUser(user.uid);
        } catch (_) {
          // La app puede seguir funcionando aunque falle el registro del token.
        }
        await _syncLocalAdvice(user.uid);
      }
    });
  }

  Future<void> _syncLocalAdvice(String uid) async {
    try {
      final snapshot = await FirebaseDatabase.instance
          .ref(
            'notificationPreferences/$uid/${NotificationTopicPreferences.localAdviceKey}',
          )
          .get();
      if (_authentication.currentUser?.uid != uid) return;
      if (snapshot.value == true) {
        await _localAdviceScheduler.scheduleHourlyAdvice();
      } else {
        await _localAdviceScheduler.cancel();
      }
    } catch (_) {
      // La app seguirá abierta aunque no pueda sincronizar el aviso local.
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
