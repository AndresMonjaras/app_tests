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
            const AuthProviderAvailability(google: false, github: false),
          ),
        ],
        child: const MaterialApp(home: AuthScreen()),
      ),
    );

    expect(find.text('Continuar con Google'), findsOneWidget);
    expect(find.text('Continuar con GitHub'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Continuar con GitHub'),
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
            const AuthProviderAvailability(google: true, github: false),
          ),
        ],
        child: const MaterialApp(home: AuthScreen()),
      ),
    );

    expect(find.text('Continuar con Google'), findsOneWidget);
    expect(find.text('Continuar con GitHub'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Continuar con GitHub'),
          )
          .onPressed,
      isNull,
    );
  });
}
