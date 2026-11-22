import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/auth/data/firebase_auth_service.dart';
import 'package:lincefood_app/features/auth/presentation/auth_controller.dart';
import 'package:lincefood_app/features/auth/presentation/auth_screen.dart';
import 'package:lincefood_app/features/navigation/auth_gate_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lincefood_app/features/auth/presentation/email_verification_screen.dart';
import 'package:lincefood_app/features/onboarding/presentation/onboarding_screen.dart';

class AuthFake implements FirebaseAuthService {
  String? code;
  int calls = 0;
  Completer<void>? pending;
  @override
  Future<void> signInWithEmail(String email, String password) async {
    calls++;
    if (code != null) throw FirebaseAuthException(code: code!);
    await pending?.future;
  }

  @override
  Future<void> signInWithGoogle() => signInWithEmail('', '');
  @override
  Future<void> signInWithGitHub() => signInWithEmail('', '');
  @override
  Future<void> recoverPassword(String email) => signInWithEmail(email, '');
  @override
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) => signInWithEmail(email, password);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SessionUser implements User {
  SessionUser(this.emailVerified);
  @override
  final bool emailVerified;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('registro informa continuidad hacia verificación', () async {
    final fake = AuthFake();
    final container = ProviderContainer(
      overrides: [firebaseAuthServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    final controller = container.read(authFormControllerProvider.notifier);
    controller.selectMode(AuthFormMode.register);
    await controller.submit(
      name: 'Ana',
      email: 'ana@example.test',
      password: '12345678',
    );
    expect(fake.calls, 1);
    expect(
      container.read(authFormControllerProvider).notice,
      contains('verificación'),
    );
  });
  test(
    'cancelar OAuth y proveedor no habilitado permiten reintentar',
    () async {
      final fake = AuthFake();
      final container = ProviderContainer(
        overrides: [
          firebaseAuthServiceProvider.overrideWithValue(fake),
          authProviderAvailabilityProvider.overrideWithValue(
            const AuthProviderAvailability(google: true, github: true),
          ),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(authFormControllerProvider.notifier);
      fake.code = 'web-context-cancelled';
      await controller.signInWithGitHub();
      expect(
        container.read(authFormControllerProvider).error,
        contains('canceló'),
      );
      fake.code = 'operation-not-allowed';
      await controller.signInWithGoogle();
      expect(
        container.read(authFormControllerProvider).error,
        contains('no está disponible'),
      );
      expect(container.read(authFormControllerProvider).isBusy, false);
    },
  );

  testWidgets('usuario nuevo pasa por verificación antes de bienvenida', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authUserProvider.overrideWith(
            (ref) => Stream.value(SessionUser(false)),
          ),
        ],
        child: const MaterialApp(home: AuthGateScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(EmailVerificationScreen), findsOneWidget);
  });
  testWidgets('sesión verificada muestra bienvenida pendiente', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authUserProvider.overrideWith(
            (ref) => Stream.value(SessionUser(true)),
          ),
        ],
        child: const MaterialApp(home: AuthGateScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(AuthScreen), findsNothing);
  });
  testWidgets('sesión vigente accede a una ruta protegida', (tester) async {
    SharedPreferences.setMockInitialValues({
      'lincefood_onboarding_complete': true,
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authUserProvider.overrideWith(
            (ref) => Stream.value(SessionUser(true)),
          ),
        ],
        child: const MaterialApp(
          home: ProtectedRoute(child: Text('Contenido privado')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Contenido privado'), findsOneWidget);
  });
  testWidgets('login cabe en pantalla chica con teclado y texto ampliado', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.4),
              viewInsets: const EdgeInsets.only(bottom: 240),
            ),
            child: child!,
          ),
          home: const AuthScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Crear cuenta nueva'));
    await tester.tap(find.text('Crear cuenta nueva'));
    await tester.pumpAndSettle();
    expect(find.text('Crea tu cuenta Lincefood'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sin sesión login aparece antes de preferencias y bienvenida', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authUserProvider.overrideWith((ref) => Stream.value(null))],
        child: const MaterialApp(home: AuthGateScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Inicia sesión'), findsOneWidget);
    expect(find.text('Pide antes de tu descanso'), findsNothing);
  });
  testWidgets('correo inválido, contraseña visible y volver de recuperación', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AuthScreen())),
    );
    await tester.ensureVisible(find.text('Entrar'));
    await tester.tap(find.text('Entrar'));
    await tester.pump();
    expect(find.text('Escribe un correo válido.'), findsOneWidget);
    await tester.tap(find.byTooltip('Mostrar contraseña'));
    await tester.pump();
    expect(find.byTooltip('Ocultar contraseña'), findsOneWidget);
    await tester.ensureVisible(find.text('Olvidé mi contraseña'));
    await tester.tap(find.text('Olvidé mi contraseña'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Volver a iniciar sesión'));
    await tester.tap(find.text('Volver a iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Inicia sesión'), findsOneWidget);
  });
  test('bloquea doble envío y cambio de modo mientras espera', () async {
    final fake = AuthFake()..pending = Completer<void>();
    final container = ProviderContainer(
      overrides: [firebaseAuthServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    final controller = container.read(authFormControllerProvider.notifier);
    final first = controller.submit(email: 'a@b.mx', password: '12345678');
    await controller.submit(email: 'a@b.mx', password: '12345678');
    controller.selectMode(AuthFormMode.recover);
    expect(fake.calls, 1);
    expect(
      container.read(authFormControllerProvider).mode,
      AuthFormMode.signIn,
    );
    fake.pending!.complete();
    await first;
    expect(container.read(authFormControllerProvider).isBusy, false);
  });
  test('errores legibles y recuperación sin enumerar cuentas', () async {
    final fake = AuthFake();
    final container = ProviderContainer(
      overrides: [
        firebaseAuthServiceProvider.overrideWithValue(fake),
        authProviderAvailabilityProvider.overrideWithValue(
          const AuthProviderAvailability(google: false, github: false),
        ),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(authFormControllerProvider.notifier);
    for (final entry in {
      'invalid-credential': 'no coinciden',
      'network-request-failed': 'conexión',
      'too-many-requests': 'Espera',
      'account-exists-with-different-credential': 'método',
    }.entries) {
      fake.code = entry.key;
      await controller.submit(email: 'a@b.mx', password: '12345678');
      expect(
        container.read(authFormControllerProvider).error,
        contains(entry.value),
      );
    }
    controller.selectMode(AuthFormMode.recover);
    fake.code = 'user-not-found';
    await controller.submit(email: 'a@b.mx', password: '');
    expect(
      container.read(authFormControllerProvider).notice,
      'Si el correo está registrado, recibirás instrucciones.',
    );
    expect(container.read(authFormControllerProvider).error, isNull);
    await controller.signInWithGoogle();
    expect(
      container.read(authFormControllerProvider).error,
      contains('no está disponible'),
    );
  });
}
