import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/admin/data/admin_panel_repository.dart';
import 'package:lincefood_app/features/admin/presentation/admin_catalog_providers.dart';
import 'package:lincefood_app/features/admin/presentation/admin_panel_screen.dart';

class _PanelFake implements AdminPanelRepository {
  final queries = <AdminUserQuery>[];
  final mutations = <(String, Map<String, Object?>)>[];

  @override
  Future<AdminUserPage> listUsers(AdminUserQuery query) async {
    queries.add(query);
    return (
      users: const [
        AdminUser(
          uid: 'cuenta',
          email: 'cuenta@example.test',
          name: 'Estudiante',
        ),
      ],
      nextPageToken: query.pageToken == null ? 'siguiente' : null,
    );
  }

  @override
  Stream<List<AdminRecord>> watchRecords(
    AdminCollection collection, {
    int? limit,
  }) => Stream.value(switch (collection) {
    AdminCollection.promotions => [
      (
        id: 'promo',
        data: {
          'title': 'Menú de prueba',
          'description': 'Prueba',
          'discountPercent': 10,
          'active': true,
          'startsAt': 100,
          'endsAt': 200,
        },
      ),
    ],
    AdminCollection.scholarships => [
      (
        id: 'titular',
        data: {'type': 'meal', 'remainingUses': 2, 'updatedAt': 123},
      ),
    ],
    AdminCollection.audit => [
      (
        id: 'evento',
        data: {
          'actorUid': 'admin',
          'action': 'upsertScholarship',
          'target': 'titular',
          'before': {'exists': false},
          'after': {'remainingUses': 2},
          'at': 123,
        },
      ),
    ],
  });

  @override
  Future<void> change(String operation, Map<String, Object?> data) async {
    mutations.add((operation, data));
  }
}

Future<void> _openPanel(
  WidgetTester tester,
  _PanelFake repo, {
  bool allowed = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminPanelAccessProvider.overrideWith((ref) async => allowed),
        adminPanelRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: const AdminPanelScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openTab(WidgetTester tester, String name) async {
  await tester.ensureVisible(find.text(name));
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('el panel no consulta usuarios sin acceso admin', (tester) async {
    final repo = _PanelFake();
    await _openPanel(tester, repo, allowed: false);
    expect(find.text('No tienes permiso para entrar al panel.'), findsOne);
    expect(find.text('Usuarios y roles'), findsNothing);
    expect(repo.queries, isEmpty);
  });

  testWidgets(
    'usuarios permite buscar, paginar y confirmar un rol de reparto',
    (tester) async {
      final repo = _PanelFake();
      await _openPanel(tester, repo);
      expect(find.text('Panel de administración'), findsOne);
      expect(find.text('Estudiante'), findsOne);
      await tester.enterText(find.byType(TextFormField).first, 'Estudiante');
      await tester.tap(find.byTooltip('Buscar usuarios'));
      await tester.pumpAndSettle();
      expect(repo.queries.last.search, 'Estudiante');

      await tester.tap(find.text('Siguiente página'));
      await tester.pumpAndSettle();
      expect(repo.queries.last.pageToken, 'siguiente');
      await tester.tap(find.byTooltip('Acciones de Estudiante'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Conceder Personal de reparto'));
      await tester.pumpAndSettle();
      expect(repo.mutations, isEmpty);
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(repo.mutations.single.$1, 'setUserRole');
      expect(repo.mutations.single.$2, {
        'uid': 'cuenta',
        'role': 'delivery_staff',
        'enabled': true,
      });
    },
  );

  testWidgets('promociones permite editar y exige confirmar desactivación', (
    tester,
  ) async {
    final repo = _PanelFake();
    await _openPanel(tester, repo);
    await _openTab(tester, 'Promociones');
    expect(find.text('Menú de prueba'), findsOne);
    await tester.tap(find.byTooltip('Acciones de Menú de prueba'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    expect(find.text('Editar promoción'), findsOne);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Título'),
      'Menú editado',
    );
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(repo.mutations.single.$1, 'upsertPromotion');
    expect(repo.mutations.single.$2['title'], 'Menú editado');

    await tester.tap(find.byTooltip('Acciones de Menú de prueba'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desactivar promoción'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(repo.mutations.length, 1);
  });

  testWidgets('becas permite asignar una beca y auditoría muestra el cambio', (
    tester,
  ) async {
    final repo = _PanelFake();
    await _openPanel(tester, repo);
    await _openTab(tester, 'Becas');
    expect(find.text('titular'), findsOne);
    await tester.tap(find.text('Asignar beca'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'UID o correo'),
      'titular',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Usos restantes'),
      '3',
    );
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(repo.mutations.single.$1, 'upsertScholarship');
    expect(repo.mutations.single.$2, {
      'uid': 'titular',
      'type': 'meal',
      'remainingUses': 3,
    });

    await _openTab(tester, 'Auditoría');
    await tester.tap(find.text('Guardar beca'));
    await tester.pumpAndSettle();
    expect(find.text('Antes'), findsOne);
    expect(find.text('Después'), findsOne);
  });
}
