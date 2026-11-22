import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../firebase_options.dart';
import 'firebase_configuration.dart';

enum FirebaseBootstrapStatus { ready, missing }

final firebaseBootstrapProvider = FutureProvider<FirebaseBootstrapStatus>((
  ref,
) async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.android);
    if (FirebaseConfiguration.useEmulators) {
      final host = FirebaseConfiguration.emulatorHost;
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);
      FirebaseDatabase.instance.useDatabaseEmulator(host, 9000);
      FirebaseStorage.instance.useStorageEmulator(host, 9199);
      FirebaseFunctions.instanceFor(region: 'us-central1')
          .useFunctionsEmulator(host, 5001);
    }
    return FirebaseBootstrapStatus.ready;
  } on FirebaseException {
    return FirebaseBootstrapStatus.missing;
  } catch (_) {
    return FirebaseBootstrapStatus.missing;
  }
});
