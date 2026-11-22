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
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));

    expect(find.text('Pide antes de tu descanso'), findsOneWidget);
    expect(find.text('Paga de forma segura'), findsOneWidget);
    expect(find.text('Recoge cuando este listo'), findsOneWidget);
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
