import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firebase_auth_gateway.dart';
import '../domain/auth_gateway.dart';

class _UnavailableAuthGateway implements AuthGateway {
  const _UnavailableAuthGateway();

  @override
  String? get currentEmail => null;

  @override
  Future<void> sendVerificationEmail() async {
    throw StateError('Firebase Authentication no está configurado.');
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    throw StateError('Firebase Authentication no está configurado.');
  }

  @override
  Future<bool> reloadUser() async => false;

  @override
  Future<void> signOut() async {}
}

final authGatewayProvider = Provider<AuthGateway>((ref) {
  if (Firebase.apps.isEmpty) return const _UnavailableAuthGateway();
  return FirebaseAuthGateway(FirebaseAuth.instance);
});
