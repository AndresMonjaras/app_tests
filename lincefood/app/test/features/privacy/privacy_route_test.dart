import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/app/app_router.dart';
import 'package:lincefood_app/features/privacy/privacy_notice_screen.dart';

void main() {
  testWidgets('la ruta del aviso de privacidad no exige sesión', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        initialRoute: AppRouter.privacy,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );

    expect(find.byType(PrivacyNoticeScreen), findsOneWidget);
  });
}
