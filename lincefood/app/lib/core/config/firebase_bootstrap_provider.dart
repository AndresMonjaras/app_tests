import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_configuration.dart';

enum FirebaseBootstrapStatus { ready, missing }

final firebaseBootstrapProvider = FutureProvider<FirebaseBootstrapStatus>((
  ref,
) async {
  final options = FirebaseConfiguration.options;
  if (options == null) return FirebaseBootstrapStatus.missing;

  try {
    await Firebase.initializeApp(options: options);
    return FirebaseBootstrapStatus.ready;
  } on FirebaseException {
    return FirebaseBootstrapStatus.missing;
  } catch (_) {
    return FirebaseBootstrapStatus.missing;
  }
});
