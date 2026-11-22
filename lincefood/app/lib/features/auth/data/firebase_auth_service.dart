import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/config/firebase_configuration.dart';

class FirebaseAuthService {
  FirebaseAuthService(this.auth);

  final FirebaseAuth auth;
  Future<void>? _googleInitialization;

  Stream<User?> get changes => auth.userChanges();
  User? get currentUser => auth.currentUser;

  Future<User> register({
    required String name,
    required String email,
    required String password,
  }) async {
    await auth.setLanguageCode('es');
    final credential = await auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No se pudo crear la cuenta.',
      );
    }
    await user.updateDisplayName(name.trim());
    await user.sendEmailVerification();
    await user.reload();
    return auth.currentUser ?? user;
  }

  Future<User> signInWithEmail(String email, String password) async {
    final result = await auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return _requireUser(result.user);
  }

  Future<User> signInWithGoogle() async {
    _googleInitialization ??= GoogleSignIn.instance.initialize(
      serverClientId: FirebaseConfiguration.googleServerClientId.isEmpty
          ? null
          : FirebaseConfiguration.googleServerClientId,
    );
    try {
      await _googleInitialization;
    } catch (_) {
      _googleInitialization = null;
      rethrow;
    }
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw FirebaseAuthException(
        code: 'missing-google-token',
        message: 'Google no entregó una credencial válida.',
      );
    }
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final result = await auth.signInWithCredential(credential);
    return _requireUser(result.user);
  }

  Future<User> signInWithFacebook() async {
    final result = await FacebookAuth.instance.login(permissions: ['email']);
    if (result.status != LoginStatus.success || result.accessToken == null) {
      throw FirebaseAuthException(
        code: 'facebook-login-cancelled',
        message: result.message ?? 'Se canceló el acceso con Facebook.',
      );
    }
    final credential = FacebookAuthProvider.credential(
      result.accessToken!.tokenString,
    );
    final authResult = await auth.signInWithCredential(credential);
    return _requireUser(authResult.user);
  }

  Future<void> resendVerification() async {
    await auth.setLanguageCode('es');
    final user = auth.currentUser;
    if (user == null || user.email == null || user.email!.trim().isEmpty) {
      throw FirebaseAuthException(
        code: 'email-required',
        message: 'La cuenta necesita un correo válido para continuar.',
      );
    }
    await user.sendEmailVerification();
  }

  Future<bool> reloadAndCheckVerification() async {
    await auth.currentUser?.reload();
    return auth.currentUser?.emailVerified ?? false;
  }

  Future<void> recoverPassword(String email) async {
    await auth.setLanguageCode('es');
    await auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() => auth.signOut();

  Future<User> _requireUser(User? user) async {
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'Firebase no devolvió una sesión válida.',
      );
    }
    if (user.email == null || user.email!.trim().isEmpty) {
      await auth.signOut();
      throw FirebaseAuthException(
        code: 'email-required',
        message: 'La cuenta necesita un correo válido para continuar.',
      );
    }
    return user;
  }
}
