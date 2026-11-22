import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/auth/presentation/auth_controller.dart';
import 'package:lincefood_app/features/auth/presentation/auth_screen.dart';

void main() {
  testWidgets('muestra ambos proveedores aunque no estén habilitados', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProviderAvailabilityProvider.overrideWithValue(
            const AuthProviderAvailability(google: false, facebook: false),
          ),
        ],
        child: const MaterialApp(home: AuthScreen()),
      ),
    );

    expect(find.text('Continuar con Google'), findsOneWidget);
    expect(find.text('Continuar con Facebook'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Continuar con Facebook'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('mantiene ambos accesos con configuración parcial', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProviderAvailabilityProvider.overrideWithValue(
            const AuthProviderAvailability(google: true, facebook: false),
          ),
        ],
        child: const MaterialApp(home: AuthScreen()),
      ),
    );

    expect(find.text('Continuar con Google'), findsOneWidget);
    expect(find.text('Continuar con Facebook'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Continuar con Facebook'),
          )
          .onPressed,
      isNull,
    );
  });
}
