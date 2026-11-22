import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/auth/data/firebase_auth_service.dart';
import 'package:lincefood_app/features/auth/presentation/auth_controller.dart';
import 'package:lincefood_app/features/auth/presentation/auth_screen.dart';

class _RecordingAuthService implements FirebaseAuthService {
  final List<String> llamadas = [];
  String? codigoError;

  @override
  Future<void> signInWithEmail(String email, String password) async {
    llamadas.add('login:$email');
    if (codigoError != null) throw FirebaseAuthException(code: codigoError!);
  }

  @override
  Future<void> signInWithGoogle() async => llamadas.add('google');

  @override
  Future<void> signInWithFacebook() async => llamadas.add('facebook');

  @override
  Future<void> recoverPassword(String email) async =>
      llamadas.add('recuperar:$email');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pumpLogin(
  WidgetTester tester, {
  required _RecordingAuthService service,
  bool google = false,
  bool facebook = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        firebaseAuthServiceProvider.overrideWithValue(service),
        authProviderAvailabilityProvider.overrideWithValue(
          AuthProviderAvailability(google: google, facebook: facebook),
        ),
      ],
      child: const MaterialApp(home: AuthScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('enviar desde el teclado en contraseña inicia sesión una vez', (
    tester,
  ) async {
    final service = _RecordingAuthService();
    await _pumpLogin(tester, service: service);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Correo electrónico'),
      'ana@example.test',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Contraseña'),
      '12345678',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(service.llamadas, ['login:ana@example.test']);
  });

  testWidgets('error de credenciales aparece en el aviso del formulario', (
    tester,
  ) async {
    final service = _RecordingAuthService()..codigoError = 'invalid-credential';
    await _pumpLogin(tester, service: service);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Correo electrónico'),
      'ana@example.test',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Contraseña'),
      '12345678',
    );
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(
      find.text('El correo o la contraseña no coinciden.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('recuperación oculta la contraseña y vuelve a iniciar sesión', (
    tester,
  ) async {
    final service = _RecordingAuthService();
    await _pumpLogin(tester, service: service);

    await tester.ensureVisible(find.text('Olvidé mi contraseña'));
    await tester.tap(find.text('Olvidé mi contraseña'));
    await tester.pumpAndSettle();

    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('Enviar instrucciones'), findsOneWidget);
    expect(find.text('Continuar con Google'), findsNothing);

    await tester.tap(find.text('Volver a iniciar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Inicia sesión'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('proveedor habilitado llama al controlador al tocarlo', (
    tester,
  ) async {
    final service = _RecordingAuthService();
    await _pumpLogin(tester, service: service, google: true);

    await tester.ensureVisible(find.text('Continuar con Google'));
    await tester.tap(find.text('Continuar con Google'));
    await tester.pumpAndSettle();

    expect(service.llamadas, ['google']);
  });
}
