import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lincefood_app/app/firebase_bootstrap_screen.dart';
import 'package:lincefood_app/core/config/firebase_bootstrap_provider.dart';
import 'package:lincefood_app/features/onboarding/presentation/onboarding_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('avanza y guarda que el onboarding terminó', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: OnboardingScreen())),
    );

    expect(find.text('Pide antes de tu descanso'), findsOneWidget);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Paga de forma segura'), findsOneWidget);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Recoge cuando esté listo'), findsOneWidget);
    await tester.tap(find.text('Comenzar'));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('lincefood_onboarding_complete'), isTrue);
  });

  testWidgets('explica cuando Firebase no está configurado', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseBootstrapProvider.overrideWith(
            (ref) async => FirebaseBootstrapStatus.missing,
          ),
        ],
        child: const MaterialApp(home: FirebaseBootstrapScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Firebase no está configurado'), findsOneWidget);
  });

  testWidgets(
    'la vista previa permite revisar onboarding y Auth sin Firebase',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: OnboardingScreen(previewMode: true)),
        ),
      );

      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Comenzar'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Vista previa sin Firebase: puedes revisar las pantallas, pero el inicio de sesión está desactivado.',
        ),
        findsOneWidget,
      );
      expect(find.text('Inicia sesión'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    },
  );
}
