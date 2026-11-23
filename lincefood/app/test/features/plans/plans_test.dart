import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/payments/domain/payment_gateway.dart';
import 'package:lincefood_app/features/payments/presentation/payment_dependencies.dart';
import 'package:lincefood_app/features/plans/data/membership_repository.dart';
import 'package:lincefood_app/features/plans/domain/service_plan.dart';
import 'package:lincefood_app/features/plans/presentation/membership_checkout.dart';
import 'package:lincefood_app/features/plans/presentation/plans_providers.dart';
import 'package:lincefood_app/features/plans/presentation/plans_screen.dart';

const _prices = {
  'campus_plus': MembershipPrices(
    amounts: {
      MembershipPeriod.weekly: 1000,
      MembershipPeriod.monthly: 3000,
      MembershipPeriod.lifetime: 30000,
    },
    demo: true,
  ),
  'campus_pro': MembershipPrices(
    amounts: {
      MembershipPeriod.weekly: 1500,
      MembershipPeriod.monthly: 5000,
      MembershipPeriod.lifetime: 50000,
    },
    demo: true,
  ),
};

class _SheetGateway implements PaymentGateway {
  _SheetGateway({this.failure});

  final Object? failure;
  String? presentedSecret;

  @override
  Future<String> createPaymentIntent(String orderId) async {
    fail('El cobro de membresía no debe usar la callable de pedidos.');
  }

  @override
  Future<void> presentPaymentSheet(String clientSecret) async {
    presentedSecret = clientSecret;
    if (failure case final error?) throw error;
  }
}

Future<void> _openPlans(
  WidgetTester tester, {
  required _SheetGateway gateway,
  Stream<Membership?>? memberships,
  void Function(String, MembershipPeriod)? onCreate,
  bool configured = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentMembershipProvider.overrideWith(
          (ref) => memberships ?? Stream<Membership?>.value(null),
        ),
        membershipPricesProvider.overrideWith((ref) => Stream.value(_prices)),
        paymentConfiguredProvider.overrideWithValue(configured),
        paymentGatewayProvider.overrideWithValue(gateway),
        createMembershipPaymentProvider.overrideWithValue((
          planId,
          period,
        ) async {
          onCreate?.call(planId, period);
          return (clientSecret: 'fake_secret', intentId: 'pi_confirmed');
        }),
      ],
      child: const MaterialApp(home: PlansScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _payButton(String amount) =>
    find.widgetWithText(FilledButton, 'Pagar \$$amount MXN');

Future<void> _seeMembershipStatus(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, 650));
  await tester.pumpAndSettle();
}

void main() {
  test('conserva los tres planes y sus beneficios de recogida', () {
    expect(servicePlans.map((p) => p.id), [
      'basico',
      'campus_plus',
      'campus_pro',
    ]);
    expect(servicePlans.map((p) => p.reservationsPerMonth), [0, 4, 8]);
    expect(servicePlans.map((p) => p.maxLeadHours), [0, 24, 48]);
  });

  test('muestra beneficios vigentes de registros nuevos y anteriores', () {
    final now = DateTime.utc(2026, 6, 1);
    final end = DateTime.utc(2026, 7, 1);
    final current = membershipFromMap({
      'planId': 'campus_pro',
      'status': 'active',
      'period': 'weekly',
      'expiresAt': end.millisecondsSinceEpoch,
      'paymentIntentId': 'pi_current',
    });
    expect(current?.currentPeriodEnd, end);
    expect(current?.hasBenefits(now), isTrue);
    expect(current?.hasBenefits(end), isFalse);
    expect(current?.appliedPayments, contains('pi_current'));

    final legacy = membershipFromMap({
      'planId': 'campus_pro',
      'status': 'canceled_at_period_end',
      'currentPeriodEnd': '2026-07-01T00:00:00Z',
      'cancelAtPeriodEnd': true,
    });
    expect(legacy?.cancelAtPeriodEnd, isTrue);
    expect(legacy?.hasBenefits(now), isTrue);

    final lifetime = membershipFromMap({
      'planId': 'campus_pro',
      'status': 'active',
      'period': 'lifetime',
    });
    expect(lifetime?.currentPeriodEnd, isNull);
    expect(lifetime?.hasBenefits(end), isTrue);
    expect(membershipFromMap({'planId': 3, 'status': 'active'}), isNull);
  });

  test('lee los precios del servidor y descarta importes inválidos', () {
    final prices = membershipPricesFromMap({
      'campus_plus': {
        'demo': true,
        'prices': {'weekly': 1700, 'monthly': '3000', 'lifetime': 0},
      },
    });
    expect(prices['campus_plus']?.demo, isTrue);
    expect(prices['campus_plus']?.amounts, {MembershipPeriod.weekly: 1700});
    expect(prices['campus_pro'], isNull);
  });

  testWidgets('el selector cambia el precio y muestra los tres planes', (
    tester,
  ) async {
    await _openPlans(tester, gateway: _SheetGateway());
    expect(find.text('Tu plan: Básico'), findsOneWidget);
    expect(find.text('Básico'), findsOneWidget);
    expect(_payButton('30.00'), findsOneWidget);

    await tester.tap(find.text('Semanal'));
    await tester.pumpAndSettle();
    expect(_payButton('10.00'), findsOneWidget);
    expect(find.text('\$10.00 MXN'), findsOneWidget);

    await tester.tap(find.text('De por vida'));
    await tester.pumpAndSettle();
    expect(_payButton('300.00'), findsOneWidget);
    await tester.scrollUntilVisible(_payButton('500.00'), 220);
    expect(find.text('Campus Pro'), findsOneWidget);
    expect(_payButton('500.00'), findsOneWidget);
  });

  testWidgets(
    'espera el cobro específico publicado por RTDB para mostrar la activación',
    (tester) async {
      final updates = StreamController<Membership?>()..add(null);
      addTearDown(updates.close);
      final gateway = _SheetGateway();
      final created = <(String, MembershipPeriod)>[];
      await _openPlans(
        tester,
        gateway: gateway,
        memberships: updates.stream,
        onCreate: (plan, period) => created.add((plan, period)),
      );

      await tester.tap(find.text('Semanal'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(_payButton('10.00'));
      await tester.tap(_payButton('10.00'));
      await tester.pumpAndSettle();
      expect(created, [('campus_plus', MembershipPeriod.weekly)]);
      expect(gateway.presentedSecret, 'fake_secret');
      expect(find.text('Esperando confirmación del pago…'), findsOneWidget);
      await _seeMembershipStatus(tester);
      expect(find.text('Tu plan: Básico'), findsOneWidget);

      final expiresAt = DateTime(2099, 11, 29, 12);
      updates.add(
        Membership(
          planId: 'campus_plus',
          status: 'active',
          period: MembershipPeriod.weekly,
          currentPeriodEnd: expiresAt,
          appliedPayments: const {'pi_other'},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Esperando confirmación del pago…'), findsOneWidget);

      updates.add(
        Membership(
          planId: 'campus_plus',
          status: 'active',
          period: MembershipPeriod.weekly,
          currentPeriodEnd: expiresAt,
          appliedPayments: const {'pi_confirmed'},
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Tu plan: Campus Plus · vence el 29 nov'),
        findsOneWidget,
      );
      expect(find.text('Esperando confirmación del pago…'), findsNothing);
    },
  );

  for (final (error, message) in [
    (const PaymentCancelledException(), 'Pago cancelado.'),
    (StateError('rechazo'), 'No se pudo procesar el pago. Inténtalo de nuevo.'),
  ]) {
    testWidgets('permite reintentar después de $message', (tester) async {
      await _openPlans(tester, gateway: _SheetGateway(failure: error));
      await tester.ensureVisible(_payButton('30.00'));
      await tester.tap(_payButton('30.00'));
      await tester.pumpAndSettle();

      expect(find.text(message), findsOneWidget);
      expect(
        tester.widget<FilledButton>(_payButton('30.00')).onPressed,
        isNotNull,
      );
      await _seeMembershipStatus(tester);
      expect(find.text('Tu plan: Básico'), findsOneWidget);
    });
  }

  testWidgets('muestra el plan de por vida y bloquea compras temporales', (
    tester,
  ) async {
    await _openPlans(
      tester,
      gateway: _SheetGateway(),
      memberships: Stream.value(
        const Membership(
          planId: 'campus_pro',
          status: 'active',
          period: MembershipPeriod.lifetime,
        ),
      ),
    );
    expect(find.text('Tu plan: Campus Pro · de por vida'), findsOneWidget);
    expect(tester.widget<FilledButton>(_payButton('30.00')).onPressed, isNull);
  });

  testWidgets('sin Stripe configurado deshabilita el pago', (tester) async {
    await _openPlans(tester, gateway: _SheetGateway(), configured: false);
    expect(find.text('Pagos no configurados.'), findsOneWidget);
    expect(tester.widget<FilledButton>(_payButton('30.00')).onPressed, isNull);
  });
}
