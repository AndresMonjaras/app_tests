import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lincefood_app/app/firebase_bootstrap_screen.dart';
import 'package:lincefood_app/core/config/firebase_bootstrap_provider.dart';
import 'package:lincefood_app/features/onboarding/presentation/onboarding_screen.dart';

void main() {
  testWidgets('muestra los tres títulos del onboarding en español', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: OnboardingScreen())),
    );

    expect(find.text('Pide antes de tu descanso'), findsOneWidget);
    expect(find.text('Paga de forma segura'), findsNothing);
    expect(find.text('Recoge cuando esté listo'), findsNothing);

    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Paga de forma segura'), findsOneWidget);
    expect(find.text('Pide antes de tu descanso'), findsNothing);

    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Recoge cuando esté listo'), findsOneWidget);
    expect(find.text('Paga de forma segura'), findsNothing);
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
}
