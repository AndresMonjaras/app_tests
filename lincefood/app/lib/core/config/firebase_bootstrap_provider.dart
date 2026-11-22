import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum FirebaseBootstrapStatus { ready, missing }

final firebaseBootstrapProvider = FutureProvider<FirebaseBootstrapStatus>((
  ref,
) async {
  try {
    await Firebase.initializeApp();
    return FirebaseBootstrapStatus.ready;
  } on FirebaseException {
    return FirebaseBootstrapStatus.missing;
  } catch (_) {
    return FirebaseBootstrapStatus.missing;
  }
});
