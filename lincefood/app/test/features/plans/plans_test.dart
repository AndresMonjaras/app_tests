import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/plans/data/membership_repository.dart';
import 'package:lincefood_app/features/plans/domain/service_plan.dart';
import 'package:lincefood_app/features/plans/presentation/plans_providers.dart';
import 'package:lincefood_app/features/plans/presentation/plans_screen.dart';

void main() {
  test('el catálogo de cliente coincide con los tres planes de prueba', () {
    expect(servicePlans.map((p) => p.id), [
      'basico',
      'campus_plus',
      'campus_pro',
    ]);
    expect(servicePlans.map((p) => p.priceCentsPerMonth), [0, 2900, 4900]);
    expect(servicePlans.map((p) => p.reservationsPerMonth), [0, 4, 8]);
    expect(servicePlans.map((p) => p.maxLeadHours), [0, 24, 48]);
  });

  test(
    'membresía solo concede beneficios con estado activo y periodo vigente',
    () {
      final now = DateTime.utc(2026, 6, 1);
      final active = Membership(
        planId: 'campus_plus',
        status: 'active',
        currentPeriodEnd: DateTime.utc(2026, 7, 1),
      );
      expect(active.hasBenefits(now), isTrue);
      expect(
        Membership(
          planId: 'campus_plus',
          status: 'past_due',
          currentPeriodEnd: DateTime.utc(2026, 7, 1),
        ).hasBenefits(now),
        isFalse,
      );
      expect(
        Membership(
          planId: 'campus_plus',
          status: 'active',
          currentPeriodEnd: DateTime.utc(2026, 5, 1),
        ).hasBenefits(now),
        isFalse,
      );
    },
  );

  test('datos de RTDB inválidos se descartan', () {
    expect(membershipFromMap(null), isNull);
    expect(membershipFromMap({'planId': 3, 'status': 'active'}), isNull);
    final parsed = membershipFromMap({
      'planId': 'campus_pro',
      'status': 'canceled_at_period_end',
      'currentPeriodEnd': '2026-07-01T00:00:00Z',
      'cancelAtPeriodEnd': true,
    });
    expect(parsed?.planId, 'campus_pro');
    expect(parsed?.cancelAtPeriodEnd, isTrue);
  });

  testWidgets('muestra los tres planes y el plan actual sin habilitar pagos', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentMembershipProvider.overrideWith(
            (ref) => Stream<Membership?>.value(
              const Membership(planId: 'campus_plus', status: 'active'),
            ),
          ),
        ],
        child: const MaterialApp(home: PlansScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Campus Plus'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Campus Pro'), 300);
    expect(find.text('Campus Pro'), findsOneWidget);
    expect(find.text('Tu plan actual'), findsOneWidget);
    expect(
      find.text('Suscripción pendiente de configuración en Stripe Sandbox.'),
      findsWidgets,
    );
    final pendingButtons = tester.widgetList<FilledButton>(
      find.widgetWithText(FilledButton, 'Pendiente de Stripe Sandbox'),
    );
    expect(pendingButtons, hasLength(1));
    expect(pendingButtons.single.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
}
