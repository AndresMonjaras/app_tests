import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/auth/domain/auth_gateway.dart';
import 'package:lincefood_app/features/auth/domain/email_verification_policy.dart';
import 'package:lincefood_app/features/auth/presentation/auth_gateway_provider.dart';
import 'package:lincefood_app/features/auth/presentation/email_verification_controller.dart';
import 'package:lincefood_app/features/auth/presentation/email_verification_screen.dart';

class _FakeAuthGateway implements AuthGateway {
  @override
  String? currentEmail = 'cliente@example.com';

  int sendCount = 0;
  bool isVerified = false;
  bool failSend = false;
  bool failReload = false;
  bool failSignOut = false;
  bool didSignOut = false;

  @override
  Future<void> sendVerificationEmail() async {
    sendCount++;
    if (failSend) throw StateError('Error ficticio de envío');
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<bool> reloadUser() async {
    if (failReload) throw StateError('Error ficticio de consulta');
    return isVerified;
  }

  @override
  Future<void> signOut() async {
    if (failSignOut) throw StateError('Error ficticio de cierre');
    didSignOut = true;
  }
}

void main() {
  group('política de reenvío', () {
    final sentAt = DateTime(2026, 1, 1, 12);

    test('permite enviar si nunca se envió y al terminar el cooldown', () {
      expect(canResendVerification(null, sentAt), isTrue);
      expect(
        canResendVerification(sentAt, sentAt.add(const Duration(seconds: 60))),
        isTrue,
      );
    });

    test('calcula los segundos restantes dentro del cooldown', () {
      expect(
        canResendVerification(sentAt, sentAt.add(const Duration(seconds: 59))),
        isFalse,
      );
      expect(
        remainingCooldownSeconds(
          sentAt,
          sentAt.add(const Duration(seconds: 20)),
        ),
        40,
      );
    });

    test('limita el resultado si el reloj está antes o después del envío', () {
      expect(
        remainingCooldownSeconds(
          sentAt,
          sentAt.subtract(const Duration(seconds: 5)),
        ),
        60,
      );
      expect(
        remainingCooldownSeconds(sentAt, sentAt.add(const Duration(hours: 2))),
        0,
      );
    });
  });

  group('EmailVerificationController', () {
    late ProviderContainer container;
    late _FakeAuthGateway gateway;

    setUp(() {
      gateway = _FakeAuthGateway();
      container = ProviderContainer(
        overrides: [authGatewayProvider.overrideWith((ref) => gateway)],
      );
    });

    tearDown(() => container.dispose());

    test('carga el correo actual y activa el cooldown tras enviar', () async {
      final controller = container.read(
        emailVerificationControllerProvider.notifier,
      );

      expect(
        container.read(emailVerificationControllerProvider).email,
        'cliente@example.com',
      );

      await controller.resendVerificationEmail();
      await controller.resendVerificationEmail();

      final state = container.read(emailVerificationControllerProvider);
      expect(gateway.sendCount, 1);
      expect(state.secondsRemaining, 60);
      expect(state.isSending, isFalse);
      expect(state.message, 'Te enviamos un correo de verificación.');
    });

    test('muestra un error si falla el reenvío', () async {
      gateway.failSend = true;
      await container
          .read(emailVerificationControllerProvider.notifier)
          .resendVerificationEmail();

      final state = container.read(emailVerificationControllerProvider);
      expect(state.isSending, isFalse);
      expect(state.error, 'No pudimos reenviar el correo. Intenta de nuevo.');
    });

    test('actualiza el mensaje según la verificación del usuario', () async {
      gateway.isVerified = true;
      await container
          .read(emailVerificationControllerProvider.notifier)
          .checkVerification();

      expect(
        container.read(emailVerificationControllerProvider).message,
        'Correo verificado. Ya puedes continuar.',
      );

      gateway.isVerified = false;
      await container
          .read(emailVerificationControllerProvider.notifier)
          .checkVerification();

      expect(
        container.read(emailVerificationControllerProvider).message,
        'Aún no confirmamos tu correo. Revisa tu bandeja.',
      );
    });

    test('cierra la sesión y reporta errores al cerrar', () async {
      final controller = container.read(
        emailVerificationControllerProvider.notifier,
      );

      expect(await controller.signOut(), isTrue);
      expect(gateway.didSignOut, isTrue);

      gateway.failSignOut = true;
      expect(await controller.signOut(), isFalse);
      expect(
        container.read(emailVerificationControllerProvider).error,
        'No pudimos cerrar la sesión. Intenta de nuevo.',
      );
    });
  });

  testWidgets('oculta las acciones si Firebase no está configurado', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: EmailVerificationScreen())),
    );

    expect(
      find.text('No hay una sesión iniciada para verificar el correo.'),
      findsOneWidget,
    );
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('deshabilita el reenvío durante el cooldown', (tester) async {
    final gateway = _FakeAuthGateway();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authGatewayProvider.overrideWith((ref) => gateway)],
        child: const MaterialApp(home: EmailVerificationScreen()),
      ),
    );

    await tester.tap(find.text('Reenviar correo'));
    await tester.pump();

    expect(find.text('Reenviar correo (60s)'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
