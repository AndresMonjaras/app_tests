import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class FirebaseAuthService {
  FirebaseAuthService(this.auth);

  final FirebaseAuth auth;
  Future<void>? _googleInitialization;

  Stream<User?> get userChanges => auth.userChanges();

  Future<void> register({
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
  }

  Future<void> signInWithEmail(String email, String password) async {
    await auth.setLanguageCode('es');
    await auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signInWithGoogle() async {
    _googleInitialization ??= GoogleSignIn.instance.initialize(
      serverClientId: _googleServerClientId.isEmpty
          ? null
          : _googleServerClientId,
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
    await _requireUser(result.user);
  }

  Future<void> signInWithFacebook() async {
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
    await _requireUser(authResult.user);
  }

  Future<void> recoverPassword(String email) async {
    await auth.setLanguageCode('es');
    await auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() => auth.signOut();

  Future<void> _requireUser(User? user) async {
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
  }
}

const _googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
