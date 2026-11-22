import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/admin/data/admin_roles_repository.dart';
import 'package:lincefood_app/features/admin/presentation/admin_catalog_providers.dart';
import 'package:lincefood_app/features/admin/presentation/admin_roles_panel.dart';

class RolesFake implements AdminRolesRepository {
  final calls = <String>[];
  Completer<void>? pending;
  bool fails = false;
  @override
  Future<void> setRole(
    String uid, {
    required bool admin,
    required bool enabled,
  }) async {
    calls.add('$uid:$admin:$enabled');
    if (fails) throw StateError('offline');
    await pending?.future;
  }
}

void main() {
  testWidgets('cancelar no cambia roles y envío pendiente bloquea acciones', (
    tester,
  ) async {
    final roles = RolesFake()..pending = Completer<void>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminAccessProvider.overrideWith((ref) async => true),
          adminRolesRepositoryProvider.overrideWithValue(roles),
        ],
        child: const MaterialApp(home: Scaffold(body: AdminRolesPanel())),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'UID de la cuenta'),
      'target',
    );
    await tester.tap(find.text('Aplicar permiso'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(roles.calls, isEmpty);
    await tester.tap(find.text('Aplicar permiso'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pump();
    expect(roles.calls, ['target:false:true']);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Guardando…'))
          .onPressed,
      isNull,
    );
    roles.pending!.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('Permiso actualizado.'), findsOneWidget);
  });
  testWidgets('error conserva formulario para reintentar', (tester) async {
    final roles = RolesFake()..fails = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [adminRolesRepositoryProvider.overrideWithValue(roles)],
        child: const MaterialApp(home: Scaffold(body: AdminRolesPanel())),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'UID de la cuenta'),
      'target',
    );
    await tester.tap(find.text('Aplicar permiso'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('No se pudo cambiar el permiso.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Aplicar permiso'),
          )
          .onPressed,
      isNotNull,
    );
  });
}
