import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/notification_preferences_gateway.dart';
import '../data/notification_inbox_gateway.dart';
import '../data/notification_tip_dismissals_gateway.dart';
import '../data/notification_token_registration.dart';
import '../domain/notification_inbox_item.dart';
import '../domain/notification_topic_preferences.dart';
import '../data/notification_service.dart';

final notificationAuthUserProvider = StreamProvider<User?>((ref) {
  if (Firebase.apps.isEmpty) return Stream<User?>.value(null);
  return FirebaseAuth.instance.authStateChanges();
});

final notificationUserIdProvider = Provider<String?>((ref) {
  return ref.watch(notificationAuthUserProvider).value?.uid;
});

final notificationInboxGatewayProvider = Provider<NotificationInboxGateway>((
  ref,
) {
  if (Firebase.apps.isEmpty) {
    throw StateError('Firebase no está configurado.');
  }
  return FirebaseNotificationInboxGateway(FirebaseDatabase.instance);
});

final notificationInboxProvider = StreamProvider<List<NotificationInboxItem>>((
  ref,
) {
  final uid = ref.watch(notificationUserIdProvider);
  if (uid == null || uid.isEmpty) {
    return Stream.value(const <NotificationInboxItem>[]);
  }
  return ref.watch(notificationInboxGatewayProvider).watch(uid);
});

final notificationTipDismissalsGatewayProvider =
    Provider<NotificationTipDismissalsGateway>((ref) {
      return FirebaseNotificationTipDismissalsGateway(
        FirebaseDatabase.instance,
      );
    });

/// Ids de consejos que el usuario activo ya eliminó.
final dismissedTipIdsProvider = StreamProvider<Set<String>>((ref) {
  final uid = ref.watch(notificationUserIdProvider);
  if (uid == null) return Stream.value(const <String>{});
  return ref.watch(notificationTipDismissalsGatewayProvider).watch(uid);
});

final notificationPreferencesGatewayProvider =
    Provider<NotificationPreferencesGateway>((ref) {
      if (Firebase.apps.isEmpty) {
        throw StateError('Firebase no está configurado.');
      }
      return FirebaseNotificationPreferencesGateway(
        FirebaseDatabase.instance,
        FirebaseMessaging.instance,
        FirebaseAuth.instance,
        ref.watch(notificationTokenRegistrationProvider),
      );
    });

class NotificationPreferencesViewState {
  const NotificationPreferencesViewState({
    required this.preferences,
    this.savingTopic,
    this.errorMessage,
  });

  final NotificationTopicPreferences preferences;
  final String? savingTopic;
  final String? errorMessage;
}

class NotificationPreferencesController
    extends AsyncNotifier<NotificationPreferencesViewState> {
  @override
  Future<NotificationPreferencesViewState> build() async {
    final uid = ref.watch(notificationUserIdProvider);
    if (uid == null || uid.isEmpty) {
      throw StateError('Inicia sesión para configurar tus notificaciones.');
    }

    final preferences = await ref
        .watch(notificationPreferencesGatewayProvider)
        .load(uid);
    return NotificationPreferencesViewState(preferences: preferences);
  }

  Future<void> setTopic(NotificationTopic topic, bool enabled) async {
    final current = state.hasValue ? state.requireValue : null;
    final uid = ref.read(notificationUserIdProvider);
    if (current == null || uid == null || uid.isEmpty) return;

    state = AsyncData(
      NotificationPreferencesViewState(
        preferences: current.preferences,
        savingTopic: topic.key,
      ),
    );

    try {
      final updated = await applyTopicPreference(
        gateway: ref.read(notificationPreferencesGatewayProvider),
        uid: uid,
        current: current.preferences,
        topic: topic,
        enabled: enabled,
      );
      state = AsyncData(NotificationPreferencesViewState(preferences: updated));
    } on StateError catch (error) {
      state = AsyncData(
        NotificationPreferencesViewState(
          preferences: current.preferences,
          errorMessage: error.message,
        ),
      );
    } catch (_) {
      state = AsyncData(
        NotificationPreferencesViewState(
          preferences: current.preferences,
          errorMessage:
              'No se pudo actualizar la preferencia. Inténtalo de nuevo.',
        ),
      );
    }
  }

  Future<void> setLocalAdvice(bool enabled) async {
    final current = state.hasValue ? state.requireValue : null;
    final uid = ref.read(notificationUserIdProvider);
    if (current == null || uid == null || uid.isEmpty) return;
    if (current.preferences.localAdvice == enabled) return;

    final updated = current.preferences.copyWith(localAdvice: enabled);
    state = AsyncData(
      NotificationPreferencesViewState(
        preferences: current.preferences,
        savingTopic: NotificationTopicPreferences.localAdviceKey,
      ),
    );

    final gateway = ref.read(notificationPreferencesGatewayProvider);
    var step = 'guardar la preferencia';
    try {
      await gateway.save(uid, updated);
      step = 'programar el consejo periódico';
      await ref
          .read(localAdvicePreferenceHandlerProvider)
          .setLocalAdviceEnabled(enabled);
      state = AsyncData(NotificationPreferencesViewState(preferences: updated));
    } catch (error, stack) {
      debugPrint('Consejo periódico: fallo al $step: $error\n$stack');
      try {
        await gateway.save(uid, current.preferences);
      } catch (_) {
        // La próxima carga vuelve a mostrar el valor persistido en Firebase.
      }
      state = AsyncData(
        NotificationPreferencesViewState(
          preferences: current.preferences,
          errorMessage:
              'No se pudo actualizar el consejo periódico. Inténtalo de nuevo.',
        ),
      );
    }
  }
}

final notificationPreferencesControllerProvider =
    AsyncNotifierProvider<
      NotificationPreferencesController,
      NotificationPreferencesViewState
    >(NotificationPreferencesController.new);
