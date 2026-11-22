import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_controller.dart';
import 'firebase_notification_service.dart';

final firebaseNotificationServiceProvider =
    Provider<FirebaseNotificationService>(
      (ref) => FirebaseNotificationService(
        messaging: FirebaseMessaging.instance,
        database: FirebaseDatabase.instance,
      ),
    );

final notificationPreferencesProvider =
    AsyncNotifierProvider<NotificationPreferencesController, Map<String, bool>>(
      NotificationPreferencesController.new,
    );

class NotificationPreferencesController
    extends AsyncNotifier<Map<String, bool>> {
  @override
  Future<Map<String, bool>> build() async {
    final user = ref.watch(authUserProvider).asData?.value;
    if (user == null || !user.emailVerified) {
      return {
        for (final topic in FirebaseNotificationService.topics.keys)
          topic: false,
      };
    }
    return ref
        .read(firebaseNotificationServiceProvider)
        .loadPreferences(user.uid);
  }

  Future<void> setPreference(String topic, bool enabled) async {
    final user = ref.read(firebaseAuthServiceProvider).currentUser;
    if (user == null || !user.emailVerified) return;
    final current =
        state.asData?.value ??
        {
          for (final item in FirebaseNotificationService.topics.keys)
            item: false,
        };
    state = const AsyncLoading();
    try {
      final changed = await ref
          .read(firebaseNotificationServiceProvider)
          .changePreference(uid: user.uid, topic: topic, enabled: enabled);
      state = AsyncData(changed ? {...current, topic: enabled} : current);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}
