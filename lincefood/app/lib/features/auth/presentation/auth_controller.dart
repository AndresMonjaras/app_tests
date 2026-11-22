import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firebase_auth_service.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

final firebaseAuthServiceProvider = Provider<FirebaseAuthService>(
  (ref) => FirebaseAuthService(ref.watch(firebaseAuthProvider)),
);

final authUserProvider = StreamProvider<User?>(
  (ref) => ref.watch(firebaseAuthServiceProvider).userChanges,
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
  }) {
    return AuthFormState(
      mode: mode ?? this.mode,
      isBusy: isBusy ?? this.isBusy,
      error: clearError ? null : error ?? this.error,
      notice: clearNotice ? null : notice ?? this.notice,
    );
  }
}

class AuthFormController extends Notifier<AuthFormState> {
  @override
  AuthFormState build() => const AuthFormState();

  void selectMode(AuthFormMode mode) {
    if (state.isBusy) return;
    state = state.copyWith(mode: mode, clearError: true, clearNotice: true);
  }

  Future<void> submit({
    required String email,
    required String password,
    String? name,
  }) async {
    final mode = state.mode;
    await _perform(() async {
      final service = ref.read(firebaseAuthServiceProvider);
      if (mode == AuthFormMode.register) {
        await service.register(
          name: name ?? '',
          email: email,
          password: password,
        );
        if (!ref.mounted) return;
        state = state.copyWith(
          notice: 'Te enviamos un correo de verificación.',
        );
      } else if (mode == AuthFormMode.signIn) {
        await service.signInWithEmail(email, password);
      } else {
        try {
          await service.recoverPassword(email);
        } on FirebaseAuthException catch (error) {
          if (error.code != 'user-not-found') rethrow;
        }
        if (!ref.mounted) return;
        state = state.copyWith(
          mode: AuthFormMode.signIn,
          notice: 'Si el correo está registrado, recibirás instrucciones.',
        );
      }
    });
  }

  Future<void> signInWithGoogle() => _perform(() async {
    if (!ref.read(authProviderAvailabilityProvider).google) {
      throw FirebaseAuthException(code: 'operation-not-allowed');
    }
    await ref.read(firebaseAuthServiceProvider).signInWithGoogle();
  });

  Future<void> signInWithGitHub() => _perform(() async {
    if (!ref.read(authProviderAvailabilityProvider).github) {
      throw FirebaseAuthException(code: 'operation-not-allowed');
    }
    await ref.read(firebaseAuthServiceProvider).signInWithGitHub();
  });

  Future<void> _perform(Future<void> Function() action) async {
    if (state.isBusy) return;
    state = state.copyWith(isBusy: true, clearError: true, clearNotice: true);
    try {
      await action();
    } on GoogleSignInException catch (error) {
      if (ref.mounted) {
        state = state.copyWith(
          error: error.code == GoogleSignInExceptionCode.canceled
              ? 'Se canceló el acceso con Google.'
              : 'No se pudo acceder con Google. Inténtalo de nuevo o usa correo y contraseña.',
        );
      }
    } on FirebaseAuthException catch (error) {
      if (ref.mounted) {
        state = state.copyWith(error: _messageFor(error));
      }
    } catch (_) {
      if (ref.mounted) {
        state = state.copyWith(
          error: 'No se pudo completar la operación. Inténtalo de nuevo.',
        );
      }
    } finally {
      if (ref.mounted) state = state.copyWith(isBusy: false);
    }
  }

  String _messageFor(FirebaseAuthException error) => switch (error.code) {
    'email-already-in-use' => 'No se pudo crear la cuenta con esos datos.',
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' => 'El correo o la contraseña no coinciden.',
    'weak-password' => 'La contraseña debe tener al menos 8 caracteres.',
    'invalid-email' => 'Escribe un correo válido.',
    'too-many-requests' => 'Espera un momento antes de volver a intentarlo.',
    'network-request-failed' => 'Revisa tu conexión e inténtalo de nuevo.',
    'operation-not-allowed' =>
      'Este método de acceso no está disponible en este momento.',
    'account-exists-with-different-credential' => 'Ya existe una cuenta con ese correo. Inicia sesión con el método que usaste antes; vincularemos este proveedor después de confirmar tu identidad.',
    'credential-already-in-use' => 'Ese proveedor ya está vinculado a otra cuenta. Inicia sesión con la cuenta que ya lo usa.',
    'popup-closed-by-user' ||
    'cancelled-popup-request' ||
    'web-context-cancelled' => 'Se canceló el acceso.',
    'missing-google-token' =>
      error.message ?? 'No se pudo obtener la credencial de Google.',
    'email-required' =>
      error.message ?? 'La cuenta necesita un correo válido para continuar.',
    _ => 'No se pudo completar la operación. Inténtalo de nuevo.',
  };
}

final authFormControllerProvider =
    NotifierProvider<AuthFormController, AuthFormState>(AuthFormController.new);

class AuthProviderAvailability {
  const AuthProviderAvailability({required this.google, required this.github});

  final bool google;
  final bool github;

  bool get hasProviders => google || github;
}

final authProviderAvailabilityProvider = Provider<AuthProviderAvailability>((
  ref,
) {
  return const AuthProviderAvailability(
    google: bool.fromEnvironment('GOOGLE_SIGN_IN_ENABLED', defaultValue: true),
    github: bool.fromEnvironment('GITHUB_SIGN_IN_ENABLED', defaultValue: true),
  );
});
