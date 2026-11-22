import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../../core/errors/domain_exception.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';

class FirebaseAuthRepository implements AuthRepository {
  const FirebaseAuthRepository(this._firebaseAuth);

  final FirebaseAuth _firebaseAuth;

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    _requireFirebaseConfiguration();
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user;

    if (user == null) {
      throw const DomainException('No fue posible iniciar sesión.');
    }

    return AuthUser(id: user.uid, email: user.email ?? email);
  }

  @override
  Future<void> signOut() async {
    _requireFirebaseConfiguration();
    await _firebaseAuth.signOut();
  }

  void _requireFirebaseConfiguration() {
    if (Firebase.apps.isEmpty) {
      throw UnimplementedError(
        'Firebase Authentication no está configurado para esta aplicación.',
      );
    }
  }
}
