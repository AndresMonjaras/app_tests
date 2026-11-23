import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/core/preferences/app_preferences_controller.dart';
import 'package:lincefood_app/features/profile/data/firebase_profile_repository.dart';
import 'package:lincefood_app/features/profile/presentation/profile_controller.dart';
import 'package:lincefood_app/features/admin/presentation/admin_catalog_providers.dart';
import 'package:lincefood_app/features/auth/presentation/auth_controller.dart';
import 'package:lincefood_app/features/biometrics/biometric_protection.dart';
import 'package:lincefood_app/features/orders/presentation/orders_providers.dart';
import 'package:lincefood_app/features/profile/presentation/profile_screen.dart';

void main() {
  for (final editor in [false, true]) {
    testWidgets(
      'el acceso al catálogo en el perfil coincide con editor=$editor',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(800, 2400);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authUserProvider.overrideWith((ref) => Stream.value(_TestUser())),
              appPreferencesProvider.overrideWith(
                _TestPreferencesController.new,
              ),
              biometricAvailabilityProvider.overrideWith((ref) async => false),
              catalogEditorAccessProvider.overrideWith((ref) async => editor),
              adminAccessProvider.overrideWith((ref) async => false),
              orderClaimsProvider.overrideWith((ref) => Stream.value({})),
              staffPermissionProvider.overrideWith((ref) async => editor),
              customerProfileProvider.overrideWith((ref) => Stream.value(null)),
              profileSyncProvider.overrideWith((ref) async => false),
              avatarEligibilityProvider.overrideWith((ref) async => false),
              avatarPresetProvider.overrideWith(
                (ref, uid) => Stream.value(null),
              ),
            ],
            child: const MaterialApp(home: ProfileScreen()),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Notificaciones', skipOffstage: false),
          findsOneWidget,
        );
        expect(
          find.text('Categorías y unidades', skipOffstage: false),
          editor ? findsOneWidget : findsNothing,
        );
      },
    );
  }
}

class _TestPreferencesController extends AppPreferencesController {
  @override
  Future<AppPreferences> build() async =>
      const AppPreferences(onboardingComplete: true);
}

class _TestUser implements User {
  @override
  String? get displayName => 'Estudiante';

  @override
  String? get email => 'estudiante@example.test';

  @override
  bool get emailVerified => true;

  @override
  String? get photoURL => null;

  @override
  List<UserInfo> get providerData => const <UserInfo>[];

  @override
  String get uid => 'test-uid';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
