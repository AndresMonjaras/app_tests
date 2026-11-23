import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/auth/presentation/auth_controller.dart';
import 'package:lincefood_app/features/profile/data/firebase_profile_repository.dart';
import 'package:lincefood_app/features/profile/presentation/profile_controller.dart';
import 'package:lincefood_app/features/profile/presentation/profile_screen.dart';

class _PasswordInfo extends Fake implements UserInfo {
  @override
  String get providerId => 'password';
  @override
  String? get photoURL => null;
}

class _Account extends Fake implements User {
  @override
  String get uid => 'perfil';
  @override
  String get displayName => 'Estudiante';
  @override
  String get email => 'perfil@example.test';
  @override
  bool get emailVerified => true;
  @override
  String? get photoURL => null;
  @override
  List<UserInfo> get providerData => [_PasswordInfo()];
}

void main() {
  for (final size in const [
    Size(360, 800),
    Size(768, 1024),
    Size(1280, 800),
    Size(1920, 1080),
  ]) {
    testWidgets('distribución del perfil en $size', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authUserProvider.overrideWith((ref) => Stream.value(_Account())),
            profileSyncProvider.overrideWith((ref) async => true),
            customerProfileProvider.overrideWith((ref) => Stream.value(null)),
            avatarEligibilityProvider.overrideWith((ref) async => true),
            avatarPresetProvider('perfil')
                .overrideWith((ref) => Stream.value(null)),
          ],
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final avatar = tester.getTopLeft(find.text('TU AVATAR'));
      final account = tester.getTopLeft(find.text('MI CUENTA'));
      final list = tester.getRect(find.byType(ListView));
      expect(list.center.dx, size.width / 2);
      if (size.width >= 1024) {
        expect(account.dx - avatar.dx, 384);
        expect(account.dy, lessThan(avatar.dy));
        expect(list.width, 1280);
      } else {
        expect(account.dx, avatar.dx);
        expect(account.dy, greaterThan(avatar.dy));
        expect(list.width, size.width.clamp(0, 640));
      }
      expect(tester.takeException(), isNull);
    });
  }
}
