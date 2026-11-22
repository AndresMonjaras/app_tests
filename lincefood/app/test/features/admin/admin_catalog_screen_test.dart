import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/admin/presentation/admin_catalog_providers.dart';
import 'package:lincefood_app/features/admin/presentation/admin_catalog_screen.dart';

void main() {
  testWidgets(
    'un falso claim admin no permite ver el catálogo de administración',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [adminAccessProvider.overrideWith((ref) async => false)],
          child: const MaterialApp(home: AdminCatalogScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('No tienes permiso para administrar el catálogo.'),
        findsOneWidget,
      );
      expect(find.text('Agregar producto'), findsNothing);
    },
  );
}
