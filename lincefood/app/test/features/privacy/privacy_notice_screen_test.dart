import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/app/app_router.dart';
import 'package:lincefood_app/features/privacy/privacy_notice_screen.dart';

void main() {
  testWidgets('el aviso explica pagos, biometría y notificaciones', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PrivacyNoticeScreen()));

    expect(find.text('Aviso de privacidad'), findsOneWidget);
    expect(find.textContaining('Borrador académico'), findsOneWidget);
    expect(find.text('Pagos'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Biometría'), 200);
    expect(
      find.textContaining('no recibe ni guarda datos biométricos'),
      findsOneWidget,
    );
  });

  testWidgets('la ruta del aviso no exige sesión', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        initialRoute: AppRouter.privacy,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );

    expect(find.byType(PrivacyNoticeScreen), findsOneWidget);
  });
}
