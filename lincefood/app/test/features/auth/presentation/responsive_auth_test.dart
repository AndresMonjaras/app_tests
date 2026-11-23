import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/auth/presentation/auth_screen.dart';
import 'package:lincefood_app/features/auth/presentation/password_reset_screen.dart';
import 'package:lincefood_app/features/auth/presentation/widgets/auth_brand_header.dart';
import 'package:lincefood_app/features/auth/presentation/widgets/auth_desktop_layout.dart';

void main() {
  for (final size in const [
    Size(360, 800),
    Size(768, 1024),
    Size(1280, 800),
    Size(1920, 1080),
  ]) {
    testWidgets('Acceso, registro y recuperación a $size', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final desktop = size.width >= 1024;
      void checkLayout() {
        expect(tester.takeException(), isNull);
        expect(
          find.byType(AuthDesktopLayout),
          desktop ? findsOneWidget : findsNothing,
        );
        if (desktop) {
          final card = tester.getRect(find.byType(Card));
          expect(card.width, 440);
          expect(
            tester.getCenter(find.text('Lincefood')).dx,
            lessThan(size.width / 2),
          );
          expect(card.left, greaterThan(size.width / 2));
          final columns = find
              .descendant(
                of: find.byType(AuthDesktopLayout),
                matching: find.byType(Row),
              )
              .first;
          final bounds = tester.getRect(columns);
          expect(bounds.width, 1280 - 48);
          expect(bounds.center.dx, size.width / 2);
        }
      }

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: AuthScreen())),
      );
      await tester.pumpAndSettle();
      checkLayout();
      expect(
        find.byType(AuthBrandHeader),
        desktop ? findsNothing : findsOneWidget,
      );
      if (!desktop) {
        expect(
          tester.getRect(find.byType(TextFormField).first).width,
          (size.width < 480 ? size.width : 480) - 48,
        );
      }
      final register = find.text('Crear cuenta nueva');
      await tester.ensureVisible(register);
      await tester.tap(register);
      await tester.pumpAndSettle();
      expect(find.text('Confirmar contraseña'), findsOneWidget);
      checkLayout();
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: PasswordResetScreen())),
      );
      await tester.pumpAndSettle();
      checkLayout();
      expect(find.text('Enviar enlace'), findsOneWidget);
    });
  }
}
