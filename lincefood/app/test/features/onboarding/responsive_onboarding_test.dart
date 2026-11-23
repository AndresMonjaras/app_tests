import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/onboarding/presentation/onboarding_screen.dart';

void main() {
  for (final size in const [
    Size(360, 800),
    Size(768, 1024),
    Size(1280, 800),
    Size(1920, 1080),
  ]) {
    testWidgets('Bienvenida y navegación a $size', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: OnboardingScreen())),
      );
      final rect = tester.getRect(find.byType(SingleChildScrollView));
      expect(rect.width, size.width >= 1024 ? 720 : size.width.clamp(0, 560));
      expect(rect.center.dx, size.width / 2);
      for (var step = 1; step <= 3; step++) {
        expect(find.text('Paso $step de 3'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (step < 3) {
          await tester.tap(find.text('Siguiente'));
          await tester.pumpAndSettle();
        }
      }
    });
  }
}
