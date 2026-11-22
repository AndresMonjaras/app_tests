import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/profile/domain/avatar_preset.dart';

void main() {
  testWidgets('el selector muestra presets y deshabilita el futuro', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: _SelectorPrueba())),
      ),
    );

    await tester.tap(find.byType(DropdownButtonFormField<AvatarPreset>));
    await tester.pumpAndSettle();
    expect(find.text('Lince masculino'), findsWidgets);
    await tester.tap(find.text('Lince masculino').last);
    await tester.pumpAndSettle();
    expect(find.text('Lince masculino'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _SelectorPrueba extends StatelessWidget {
  const _SelectorPrueba();

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<AvatarPreset>(
      initialValue: AvatarPreset.neutro,
      items: [
        for (final preset in AvatarPreset.values)
          DropdownMenuItem(
            value: preset,
            enabled: preset.available,
            child: Text(
              preset.available
                  ? preset.label
                  : '${preset.label} · Próximamente',
            ),
          ),
      ],
      onChanged: (_) {},
    );
  }
}
