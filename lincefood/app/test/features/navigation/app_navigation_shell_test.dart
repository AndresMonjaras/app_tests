import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/auth/presentation/auth_controller.dart';
import 'package:lincefood_app/features/biometrics/biometric_protection.dart';
import 'package:lincefood_app/features/catalog/data/in_memory_catalog_repository.dart';
import 'package:lincefood_app/features/catalog/domain/product.dart';
import 'package:lincefood_app/features/catalog/presentation/catalog_providers.dart';
import 'package:lincefood_app/features/location/presentation/location_providers.dart';
import 'package:lincefood_app/features/navigation/app_navigation_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpShell(
  WidgetTester tester,
  Size size, {
  double scale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authUserProvider.overrideWith((ref) => Stream.value(null)),
        catalogRepositoryProvider.overrideWithValue(
          InMemoryCatalogRepository([
            Product(
              id: 'cafe',
              name: 'Café',
              priceCents: 3000,
              categoryId: 'Bebidas',
            ),
          ]),
        ),
        cafeteriaLocationProvider.overrideWith((ref) => Stream.value(null)),
        biometricAvailabilityProvider.overrideWith((ref) async => false),
      ],
      child: MaterialApp(home: _ScaledShell(scale: scale)),
    ),
  );
  await tester.pumpAndSettle();
}

class _ScaledShell extends StatelessWidget {
  const _ScaledShell({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: const AppNavigationShell(),
    );
  }
}

void main() {
  testWidgets('usa navegación inferior en teléfono', (tester) async {
    await _pumpShell(tester, const Size(360, 800));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('usa NavigationRail en ventana ancha con texto ampliado', (
    tester,
  ) async {
    await _pumpShell(tester, const Size(1280, 800), scale: 1.6);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Inicio'), findsWidgets);
    expect(find.text('Perfil'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
