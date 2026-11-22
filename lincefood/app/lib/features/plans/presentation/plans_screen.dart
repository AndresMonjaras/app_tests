import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../domain/service_plan.dart';
import 'plans_providers.dart';

const _pendingCheckoutNotice =
    'Suscripción pendiente de configuración en Stripe Sandbox.';

class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(currentMembershipProvider);
    final now = DateTime.now();
    final currentPlanId = membership.value?.planId ?? 'basico';

    return Scaffold(
      appBar: AppBar(title: const Text('Planes de servicio')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Los planes reservan horarios de recogida. No cambian pedidos ya confirmados por la cafetería. Los precios son de prueba.',
          ),
          const SizedBox(height: 16),
          _MembershipStatus(
            loading: membership.isLoading,
            membership: membership.value,
            now: now,
          ),
          const SizedBox(height: 16),
          for (final plan in servicePlans)
            _PlanCard(plan: plan, isCurrent: plan.id == currentPlanId),
        ],
      ),
    );
  }
}

class _MembershipStatus extends StatelessWidget {
  const _MembershipStatus({
    required this.loading,
    required this.membership,
    required this.now,
  });

  final bool loading;
  final Membership? membership;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const LinearProgressIndicator(semanticsLabel: 'Cargando plan');
    }
    final current = membership;
    final text = current == null
        ? 'Plan actual: Básico.'
        : _describe(current, now);
    return Card(
      child: Padding(padding: const EdgeInsets.all(16), child: Text(text)),
    );
  }

  String _describe(Membership membership, DateTime now) {
    final plan = servicePlanById(membership.planId);
    final name = plan?.name ?? 'Desconocido';
    final end = membership.currentPeriodEnd;
    if (membership.status == 'past_due') {
      return 'Plan actual: $name. Pago pendiente; los beneficios están suspendidos.';
    }
    if (membership.hasBenefits(now) && end != null) {
      final until = _formatDate(end);
      return membership.cancelAtPeriodEnd
          ? 'Plan actual: $name. La renovación está cancelada; beneficios hasta $until.'
          : 'Plan actual: $name. Beneficios activos hasta $until.';
    }
    return 'Plan actual: $name. Sin beneficios activos.';
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.isCurrent});

  final ServicePlan plan;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final price = plan.isPaid
        ? '${formatMoney(plan.priceCentsPerMonth)} al mes (prueba)'
        : 'Sin costo';
    final String buttonLabel;
    if (isCurrent) {
      buttonLabel = 'Tu plan actual';
    } else if (plan.isPaid) {
      buttonLabel = 'Pendiente de Stripe Sandbox';
    } else {
      buttonLabel = 'Plan predeterminado';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(plan.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(price),
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
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: null, child: Text(buttonLabel)),
            ),
            if (plan.isPaid && !isCurrent)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _pendingCheckoutNotice,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

ServicePlan? servicePlanById(String id) {
  for (final plan in servicePlans) {
    if (plan.id == id) return plan;
  }
  return null;
}

String _formatDate(DateTime date) {
  final local = date.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}
