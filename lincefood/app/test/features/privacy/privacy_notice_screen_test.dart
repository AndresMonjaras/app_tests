import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/privacy/privacy_notice_screen.dart';

void main() {
  testWidgets('el aviso explica datos y mantiene visibles los pendientes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: const PrivacyNoticeScreen(),
      ),
    );

    expect(find.text('Aviso de Privacidad'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Quién es responsable'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.textContaining('Instituto Tecnológico de Celaya'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Datos que utiliza la aplicación'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Datos que utiliza la aplicación'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Conservación y eliminación'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Conservación y eliminación'), findsOneWidget);
    expect(find.textContaining('90 días'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
