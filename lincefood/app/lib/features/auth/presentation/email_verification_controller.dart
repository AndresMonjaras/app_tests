import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firebase_auth_gateway.dart';
import '../domain/auth_gateway.dart';
import '../domain/email_verification_policy.dart';

final authGatewayProvider = Provider<AuthGateway>((ref) {
  return FirebaseAuthGateway(FirebaseAuth.instance);
});

const Object _unchanged = Object();

@immutable
class EmailVerificationState {
  const EmailVerificationState({
    required this.email,
    this.lastSentAt,
    this.secondsRemaining = 0,
    this.isSending = false,
    this.isVerifying = false,
    this.message,
    this.error,
  });

  final String email;
  final DateTime? lastSentAt;
  final int secondsRemaining;
  final bool isSending;
  final bool isVerifying;
  final String? message;
  final String? error;

  bool get canResend =>
      email.isNotEmpty && !isSending && secondsRemaining == 0;

  EmailVerificationState copyWith({
    DateTime? lastSentAt,
    int? secondsRemaining,
    bool? isSending,
    bool? isVerifying,
    Object? message = _unchanged,
    Object? error = _unchanged,
  }) {
    return EmailVerificationState(
      email: email,
      lastSentAt: lastSentAt ?? this.lastSentAt,
      secondsRemaining: secondsRemaining ?? this.secondsRemaining,
      isSending: isSending ?? this.isSending,
      isVerifying: isVerifying ?? this.isVerifying,
      message: identical(message, _unchanged) ? this.message : message as String?,
      error: identical(error, _unchanged) ? this.error : error as String?,
    );
  }
}

class EmailVerificationController extends Notifier<EmailVerificationState> {
  Timer? _timer;

  @override
  EmailVerificationState build() {
    ref.onDispose(() => _timer?.cancel());
    final gateway = ref.read(authGatewayProvider);
    return EmailVerificationState(email: gateway.currentEmail ?? '');
  }

  Future<void> resendVerificationEmail() async {
    if (!state.canResend) return;

    state = state.copyWith(isSending: true, message: null, error: null);
    try {
      await ref.read(authGatewayProvider).sendVerificationEmail();
      final sentAt = DateTime.now();
      state = state.copyWith(
        isSending: false,
        lastSentAt: sentAt,
        secondsRemaining: resendCooldownSeconds,
        message: 'Te enviamos un correo de verificación.',
      );
      _startCountdown();
    } catch (_) {
      state = state.copyWith(
        isSending: false,
        error: 'No pudimos reenviar el correo. Intenta de nuevo.',
      );
    }
  }

  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = remainingCooldownSeconds(
        state.lastSentAt,
        DateTime.now(),
      );
      if (remaining == 0) {
        timer.cancel();
        _timer = null;
      }
      state = state.copyWith(secondsRemaining: remaining);
    });
  }

  Future<void> checkVerification() async {
    if (state.email.isEmpty || state.isVerifying) return;

    state = state.copyWith(isVerifying: true, message: null, error: null);
    try {
      final verified = await ref.read(authGatewayProvider).reloadUser();
      state = state.copyWith(
        isVerifying: false,
        message: verified
            ? 'Correo verificado. Ya puedes continuar.'
            : 'Aún no confirmamos tu correo. Revisa tu bandeja.',
      );
    } catch (_) {
      state = state.copyWith(
        isVerifying: false,
        error: 'No pudimos revisar el estado del correo. Intenta de nuevo.',
      );
    }
  }

  Future<bool> signOut() async {
    try {
      await ref.read(authGatewayProvider).signOut();
      return true;
    } catch (_) {
      state = state.copyWith(
        error: 'No pudimos cerrar la sesión. Intenta de nuevo.',
      );
      return false;
    }
  }
}

final emailVerificationControllerProvider =
    NotifierProvider<EmailVerificationController, EmailVerificationState>(
  EmailVerificationController.new,
);
