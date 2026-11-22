import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class FirebaseAuthService {
  FirebaseAuthService(this.auth);

  final FirebaseAuth auth;
  Future<void>? _googleInitialization;
  AuthCredential? _credentialAwaitingAccountSignIn;
  String? _emailAwaitingAccountSignIn;

  User? get currentUser => auth.currentUser;

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
    final result = await auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await _linkPendingCredential(result.user);
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
    late final UserCredential result;
    try {
      result = await auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (error) {
      _rememberCredentialForLinking(error, credential);
      rethrow;
    }
    await _requireUser(result.user);
    await _linkPendingCredential(result.user);
  }

  Future<void> signInWithGitHub() async {
    final provider = GithubAuthProvider();
    provider.addScope('user:email');
    late final UserCredential authResult;
    try {
      authResult = kIsWeb
          ? await auth.signInWithPopup(provider)
          : await auth.signInWithProvider(provider);
    } on FirebaseAuthException catch (error) {
      _rememberCredentialForLinking(error, error.credential);
      rethrow;
    }
    await _requireUser(authResult.user);
    await _linkPendingCredential(authResult.user);
  }

  Future<void> recoverPassword(String email) async {
    await auth.setLanguageCode('es');
    await auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() async {
    await auth.signOut();
    _clearPendingLink();
  }

  void _rememberCredentialForLinking(
    FirebaseAuthException error,
    AuthCredential? fallbackCredential,
  ) {
    if (error.code != 'account-exists-with-different-credential') return;
    final pendingCredential = error.credential ?? fallbackCredential;
    final email = error.email?.trim().toLowerCase();
    if (pendingCredential == null || email == null || email.isEmpty) return;
    _credentialAwaitingAccountSignIn = pendingCredential;
    _emailAwaitingAccountSignIn = email;
  }

  Future<void> _linkPendingCredential(User? user) async {
    final pendingCredential = _credentialAwaitingAccountSignIn;
    final pendingEmail = _emailAwaitingAccountSignIn;
    if (pendingCredential == null || pendingEmail == null || user == null) {
      return;
    }

    if (user.email?.trim().toLowerCase() != pendingEmail) {
      _clearPendingLink();
      return;
    }

    try {
      await user.linkWithCredential(pendingCredential);
      _clearPendingLink();
    } on FirebaseAuthException catch (error) {
      if (error.code != 'network-request-failed' &&
          error.code != 'too-many-requests') {
        _clearPendingLink();
      }
      rethrow;
    }
  }

  void _clearPendingLink() {
    _credentialAwaitingAccountSignIn = null;
    _emailAwaitingAccountSignIn = null;
  }

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
