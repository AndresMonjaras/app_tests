import 'package:firebase_auth/firebase_auth.dart';

import '../domain/auth_gateway.dart';

class FirebaseAuthGateway implements AuthGateway {
  const FirebaseAuthGateway(this._firebaseAuth);

  final FirebaseAuth _firebaseAuth;

  @override
  String? get currentEmail => _firebaseAuth.currentUser?.email;

  @override
  Future<void> sendVerificationEmail() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw StateError('No hay una sesión activa para verificar el correo.');
    }

    await user.sendEmailVerification();
  }

  @override
  Future<bool> reloadUser() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return false;

    await user.reload();
    return _firebaseAuth.currentUser?.emailVerified ?? false;
  }

  @override
  Future<void> signOut() => _firebaseAuth.signOut();
}
