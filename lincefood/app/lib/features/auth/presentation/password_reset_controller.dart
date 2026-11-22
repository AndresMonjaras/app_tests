import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/password_reset_policy.dart';
import 'auth_gateway_provider.dart';

const Object _sinCambios = Object();

class PasswordResetState {
  const PasswordResetState({
    this.enviando = false,
    this.segundosRestantes = 0,
    this.mensaje,
    this.error,
  });

  final bool enviando;
  final int segundosRestantes;
  final String? mensaje;
  final String? error;

  bool get puedeEnviar => !enviando && segundosRestantes == 0;

  PasswordResetState copyWith({
    bool? enviando,
    int? segundosRestantes,
    Object? mensaje = _sinCambios,
    Object? error = _sinCambios,
  }) {
    return PasswordResetState(
      enviando: enviando ?? this.enviando,
      segundosRestantes: segundosRestantes ?? this.segundosRestantes,
      mensaje: identical(mensaje, _sinCambios)
          ? this.mensaje
          : mensaje as String?,
      error: identical(error, _sinCambios) ? this.error : error as String?,
    );
  }
}

class PasswordResetController extends Notifier<PasswordResetState> {
  Timer? _temporizador;

  @override
  PasswordResetState build() {
    ref.onDispose(() => _temporizador?.cancel());
    return const PasswordResetState();
  }

  Future<void> enviar(String correo) async {
    if (!esCorreoValido(correo)) {
      state = state.copyWith(error: 'Escribe un correo válido.', mensaje: null);
      return;
    }
    if (!state.puedeEnviar) return;

    state = state.copyWith(enviando: true, error: null, mensaje: null);

    try {
      await ref.read(authGatewayProvider).sendPasswordResetEmail(correo.trim());
    } catch (_) {
      // El mensaje no revela si el correo está registrado.
    }

    if (!ref.mounted) return;

    state = state.copyWith(
      enviando: false,
      segundosRestantes: cooldownSolicitudContrasena.inSeconds,
      mensaje: 'Si el correo existe, enviamos un enlace.',
    );
    _iniciarCooldown();
  }

  void _iniciarCooldown() {
    _temporizador?.cancel();
    _temporizador = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!ref.mounted) {
        timer.cancel();
        _temporizador = null;
        return;
      }

      final siguiente = state.segundosRestantes - 1;
      if (siguiente <= 0) {
        timer.cancel();
        _temporizador = null;
        state = state.copyWith(segundosRestantes: 0);
      } else {
        state = state.copyWith(segundosRestantes: siguiente);
      }
    });
  }
}

final passwordResetControllerProvider =
    NotifierProvider<PasswordResetController, PasswordResetState>(
      PasswordResetController.new,
    );
