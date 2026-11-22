import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../payments/presentation/payment_dependencies.dart';
import '../domain/service_plan.dart';
import 'membership_checkout.dart';
import 'plans_providers.dart';

class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(currentMembershipProvider);
    final prices = ref.watch(membershipPricesProvider);
    final configured = ref.watch(paymentConfiguredProvider);
    final checkout = ref.watch(membershipCheckoutProvider);
    final controller = ref.read(membershipCheckoutProvider.notifier);
    final current = membership.value;
    final active = current?.hasBenefits(DateTime.now()) == true
        ? current
        : null;
    final currentPlan = _servicePlanById(active?.planId ?? 'basico');
    final intentId = checkout.intentId;
    final confirming =
        intentId != null && current?.appliedPayments.contains(intentId) != true;
    final canPay =
        configured && !checkout.busy && !confirming && membership is AsyncData;
    final paymentMessage = checkout.busy
        ? 'Iniciando pago…'
        : confirming
        ? 'Esperando confirmación del pago…'
        : checkout.message;

    return Scaffold(
      appBar: AppBar(title: const Text('Planes de servicio')),
      bottomNavigationBar: paymentMessage == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Semantics(liveRegion: true, child: Text(paymentMessage)),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (membership.isLoading)
            const LinearProgressIndicator(semanticsLabel: 'Cargando plan')
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  membership.hasError
                      ? 'No se pudo consultar tu plan.'
                      : _describeMembership(active, currentPlan),
                ),
              ),
            ),
          const SizedBox(height: 16),
          SegmentedButton<MembershipPeriod>(
            showSelectedIcon: false,
            segments: [
              for (final period in MembershipPeriod.values)
                ButtonSegment(value: period, label: Text(period.label)),
            ],
            selected: {checkout.period},
            onSelectionChanged: checkout.busy
                ? null
                : (selection) => controller.selectPeriod(selection.single),
          ),
          if (prices.isLoading)
            const LinearProgressIndicator(semanticsLabel: 'Cargando precios')
          else if (prices.hasError)
            const Text('No se pudieron consultar los precios.'),
          if (!configured) const Text('Pagos no configurados.'),
          const SizedBox(height: 16),
          for (final plan in servicePlans)
            _PlanCard(
              plan: plan,
              isCurrent: plan.id == currentPlan?.id && membership is AsyncData,
              price: prices.value?[plan.id]?.amounts[checkout.period],
              demo: prices.value?[plan.id]?.demo ?? false,
              onPay:
                  canPay &&
                      (active?.period != MembershipPeriod.lifetime ||
                          (checkout.period == MembershipPeriod.lifetime &&
                              plan.reservationsPerMonth >
                                  (currentPlan?.reservationsPerMonth ?? 0)))
                  ? () => controller.pay(plan.id)
                  : null,
            ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.isCurrent,
    required this.price,
    required this.demo,
    required this.onPay,
  });

  final ServicePlan plan;
  final bool isCurrent;
  final int? price;
  final bool demo;
  final VoidCallback? onPay;

  @override
  Widget build(BuildContext context) {
    final amount = price;
    final priceLabel = !plan.isPaid
        ? 'Sin costo'
        : amount == null
        ? 'Precio no disponible'
        : '${formatMoney(amount)}${demo ? ' (demostración)' : ''}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(plan.name, style: Theme.of(context).textTheme.titleLarge),
            if (isCurrent) const Text('Tu plan actual'),
            const SizedBox(height: 4),
            Text(priceLabel),
            const SizedBox(height: 12),
            const Text(
              'Consulta, compra, seguimiento, QR y avisos: incluidos.',
            ),
            Text(
              plan.reservationsPerMonth == 0
                  ? 'Sin reservas de horario.'
                  : '${plan.reservationsPerMonth} reservas de horario al mes.',
            ),
            if (plan.maxLeadHours > 0)
              Text(
                'Reserva hasta ${plan.maxLeadHours} h antes de la recogida.',
              ),
            if (plan.isPaid && amount != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onPay,
                  child: Text('Pagar ${formatMoney(amount)}'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

ServicePlan? _servicePlanById(String id) {
  for (final plan in servicePlans) {
    if (plan.id == id) return plan;
  }
  return null;
}

String _describeMembership(Membership? membership, ServicePlan? plan) {
  final name = plan?.name ?? 'Desconocido';
  if (membership == null) return 'Tu plan: $name';
  if (membership.period == MembershipPeriod.lifetime) {
    return 'Tu plan: $name · de por vida';
  }
  final end = membership.currentPeriodEnd?.toLocal();
  if (end == null) return 'Tu plan: $name';
  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  return 'Tu plan: $name · vence el ${end.day} ${months[end.month - 1]}';
}
