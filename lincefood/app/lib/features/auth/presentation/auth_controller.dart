import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/firebase_auth_service.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

final firebaseAuthServiceProvider = Provider<FirebaseAuthService>(
  (ref) => FirebaseAuthService(ref.watch(firebaseAuthProvider)),
);

final authUserProvider = StreamProvider<User?>(
  (ref) => ref.watch(firebaseAuthServiceProvider).changes,
);

enum AuthFormMode { signIn, register, recover }

@immutable
class AuthFormState {
  const AuthFormState({
    this.mode = AuthFormMode.signIn,
    this.isBusy = false,
    this.error,
    this.notice,
  });

  final AuthFormMode mode;
  final bool isBusy;
  final String? error;
  final String? notice;

  AuthFormState copyWith({
    AuthFormMode? mode,
    bool? isBusy,
    String? error,
    String? notice,
    bool clearError = false,
    bool clearNotice = false,
  }) => AuthFormState(
    mode: mode ?? this.mode,
    isBusy: isBusy ?? this.isBusy,
    error: clearError ? null : error ?? this.error,
    notice: clearNotice ? null : notice ?? this.notice,
  );
}

class AuthFormController extends Notifier<AuthFormState> {
  @override
  AuthFormState build() => const AuthFormState();

  void selectMode(AuthFormMode mode) {
    state = state.copyWith(mode: mode, clearError: true, clearNotice: true);
  }

  Future<void> submit({
    required String email,
    required String password,
    String? name,
  }) => _perform(() async {
    final service = ref.read(firebaseAuthServiceProvider);
    if (state.mode == AuthFormMode.register) {
      final user = await service.register(
        name: name ?? '',
        email: email,
        password: password,
      );
      await _saveVerificationTimestamp(user);
      state = state.copyWith(notice: 'Te enviamos un correo de verificación.');
    } else if (state.mode == AuthFormMode.signIn) {
      await service.signInWithEmail(email, password);
    } else {
      await service.recoverPassword(email);
      state = state.copyWith(
        mode: AuthFormMode.signIn,
        notice: 'Si el correo está registrado, recibirás instrucciones.',
      );
    }
  });

  Future<void> signInWithGoogle() => _perform(() async {
    final user = await ref.read(firebaseAuthServiceProvider).signInWithGoogle();
    await _sendVerificationIfNeeded(user);
  });

  Future<void> signInWithFacebook() => _perform(() async {
    final user = await ref
        .read(firebaseAuthServiceProvider)
        .signInWithFacebook();
    await _sendVerificationIfNeeded(user);
  });

  Future<void> _sendVerificationIfNeeded(User user) async {
    if (!user.emailVerified) {
      await user.sendEmailVerification();
      await _saveVerificationTimestamp(user);
      state = state.copyWith(
        notice: 'Verifica tu correo antes de continuar con tus pedidos.',
      );
    }
  }

  Future<void> _saveVerificationTimestamp(User user) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(
      'verification_sent_at_${user.uid}',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> _perform(Future<void> Function() action) async {
    state = state.copyWith(isBusy: true, clearError: true, clearNotice: true);
    try {
      await action();
    } on FirebaseAuthException catch (error) {
      state = state.copyWith(error: _messageFor(error));
    } catch (_) {
      state = state.copyWith(
        error: 'No se pudo completar la operación. Revisa tu conexión e inténtalo de nuevo.',
      );
    } finally {
      state = state.copyWith(isBusy: false);
    }
  }

  String _messageFor(FirebaseAuthException error) => switch (error.code) {
    'email-already-in-use' => 'Ese correo ya tiene una cuenta. Inicia sesión.',
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' => 'El correo o la contraseña no coinciden.',
    'weak-password' => 'Usa una contraseña más segura.',
    'invalid-email' => 'Escribe un correo válido.',
    'too-many-requests' => 'Espera antes de volver a intentarlo.',
    'operation-not-allowed' => 'Ese proveedor no está habilitado en Firebase.',
    'email-required' => error.message ?? 'La cuenta requiere un correo válido.',
    'account-exists-with-different-credential' => 'Ese correo ya está asociado a otro método. Inicia sesión con el método que usaste antes.',
    'facebook-login-cancelled' =>
      error.message ?? 'Se canceló el acceso con Facebook.',
    'missing-google-token' =>
      error.message ?? 'No se pudo obtener la credencial de Google.',
    _ => error.message ?? 'No se pudo autenticar la cuenta.',
  };
}

final authFormControllerProvider =
    NotifierProvider<AuthFormController, AuthFormState>(AuthFormController.new);
