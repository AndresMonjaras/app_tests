import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/auth/domain/auth_gateway.dart';
import 'package:lincefood_app/features/auth/presentation/auth_gateway_provider.dart';
import 'package:lincefood_app/features/auth/presentation/password_reset_controller.dart';

class _GatewayFalso implements AuthGateway {
  int llamadas = 0;
  bool falla = false;
  Completer<void>? pendiente;

  @override
  String? get currentEmail => null;

  @override
  Future<void> sendVerificationEmail() async {}

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    llamadas++;
    if (pendiente != null) return pendiente!.future;
    if (falla) throw StateError('Error simulado');
  }

  @override
  Future<bool> reloadUser() async => false;

  @override
  Future<void> signOut() async {}
}

void main() {
  test('correo inválido no consulta al gateway', () async {
    final gateway = _GatewayFalso();
    final container = ProviderContainer(
      overrides: [authGatewayProvider.overrideWithValue(gateway)],
    );
    addTearDown(container.dispose);

    await container
        .read(passwordResetControllerProvider.notifier)
        .enviar('correo-invalido');

    final estado = container.read(passwordResetControllerProvider);
    expect(gateway.llamadas, 0);
    expect(estado.segundosRestantes, 0);
    expect(estado.error, 'Escribe un correo válido.');
  });

  test('muestra un mensaje genérico aunque falle el gateway', () async {
    final gateway = _GatewayFalso()..falla = true;
    final container = ProviderContainer(
      overrides: [authGatewayProvider.overrideWithValue(gateway)],
    );
    addTearDown(container.dispose);

    await container
        .read(passwordResetControllerProvider.notifier)
        .enviar('usuario@dominio.com');

    final estado = container.read(passwordResetControllerProvider);
    expect(gateway.llamadas, 1);
    expect(estado.mensaje, 'Si el correo existe, enviamos un enlace.');
    expect(estado.error, isNull);
    expect(estado.segundosRestantes, 60);
  });

  testWidgets(
    'mantiene el cooldown de 60 segundos antes de permitir otro envío',
    (tester) async {
      final gateway = _GatewayFalso();
      final container = ProviderContainer(
        overrides: [authGatewayProvider.overrideWithValue(gateway)],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        passwordResetControllerProvider.notifier,
      );
      await controller.enviar('usuario@dominio.com');
      expect(
        container.read(passwordResetControllerProvider).segundosRestantes,
        60,
      );

      await controller.enviar('usuario@dominio.com');
      expect(gateway.llamadas, 1);

      await tester.pump(const Duration(seconds: 30));
      expect(
        container.read(passwordResetControllerProvider).segundosRestantes,
        30,
      );
      await tester.pump(const Duration(seconds: 30));
      expect(
        container.read(passwordResetControllerProvider).puedeEnviar,
        isTrue,
      );

      await controller.enviar('usuario@dominio.com');
      expect(gateway.llamadas, 2);
      container.dispose();
    },
  );

  test(
    'no escribe estado si el provider se dispone durante el envío',
    () async {
      final gateway = _GatewayFalso()..pendiente = Completer<void>();
      final container = ProviderContainer(
        overrides: [authGatewayProvider.overrideWithValue(gateway)],
      );
      final solicitud = container
          .read(passwordResetControllerProvider.notifier)
          .enviar('usuario@dominio.com');

      container.dispose();
      gateway.pendiente!.complete();

      await expectLater(solicitud, completes);
    },
  );
}
