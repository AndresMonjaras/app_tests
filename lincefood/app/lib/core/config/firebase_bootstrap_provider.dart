import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../notifications/notification_providers.dart';
import 'firebase_configuration.dart';

enum FirebaseBootstrapStatus { ready, missing }

final firebaseBootstrapProvider = FutureProvider<FirebaseBootstrapStatus>((
  ref,
) async {
  try {
    final options = FirebaseConfiguration.options;
    if (Firebase.apps.isEmpty && options == null) {
      return FirebaseBootstrapStatus.missing;
    }
    final app = Firebase.apps.isEmpty
        ? await Firebase.initializeApp(options: options!)
        : Firebase.app();

    if (FirebaseConfiguration.useEmulators && !kReleaseMode) {
      final host = FirebaseConfiguration.emulatorHost;
      await FirebaseAuth.instanceFor(app: app).useAuthEmulator(host, 9199);
      FirebaseDatabase.instanceFor(app: app).useDatabaseEmulator(host, 9000);
      FirebaseStorage.instanceFor(app: app).useStorageEmulator(host, 9298);
      FirebaseFunctions.instanceFor(
        app: app,
        region: 'us-central1',
      ).useFunctionsEmulator(host, 5001);
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await FirebaseAppCheck.instanceFor(app: app).activate(
          providerAndroid: kReleaseMode
              ? const AndroidPlayIntegrityProvider()
              : const AndroidDebugProvider(),
        );
      } catch (_) {
        if (kReleaseMode) rethrow;
      }
    }

    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      FirebaseDatabase.instanceFor(app: app).setPersistenceEnabled(true);
    }

    final notificationService = ref.read(firebaseNotificationServiceProvider);
    await notificationService.initialize();
    ref.onDispose(notificationService.dispose);
    return FirebaseBootstrapStatus.ready;
  } on FirebaseException {
    return FirebaseBootstrapStatus.missing;
  } catch (_) {
    return FirebaseBootstrapStatus.missing;
  }
});
