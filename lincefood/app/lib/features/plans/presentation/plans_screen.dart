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

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Planes de servicio')),
      bottomNavigationBar: paymentMessage == null
          ? null
          : _PaymentStatusBar(
              message: paymentMessage,
              isWorking: checkout.busy || confirming,
            ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _ActivePlanStatusCard(
                membership: membership,
                active: active,
                currentPlan: currentPlan,
              ),
              const SizedBox(height: 16),
              _PeriodSelectorSection(
                checkout: checkout,
                controller: controller,
              ),
              if (prices.isLoading) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(
                  semanticsLabel: 'Cargando precios',
                ),
              ] else if (prices.hasError) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: colorScheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No se pudieron consultar los precios.',
                          style: TextStyle(
                            color: colorScheme.onErrorContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (!configured) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.tertiaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.tertiary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: colorScheme.onTertiaryContainer,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Pagos no configurados.',
                          style: TextStyle(
                            color: colorScheme.onTertiaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              for (final plan in servicePlans)
                _PlanCard(
                  plan: plan,
                  isCurrent:
                      plan.id == currentPlan?.id && membership is AsyncData,
                  price: prices.value?[plan.id]?.amounts[checkout.period],
                  period: checkout.period,
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
        ),
      ),
    );
  }
}

class _ActivePlanStatusCard extends StatelessWidget {
  const _ActivePlanStatusCard({
    required this.membership,
    required this.active,
    required this.currentPlan,
  });

  final AsyncValue<Membership?> membership;
  final Membership? active;
  final ServicePlan? currentPlan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    if (membership.isLoading) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Consultando membresía…',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const LinearProgressIndicator(semanticsLabel: 'Cargando plan'),
            ],
          ),
        ),
      );
    }

    final hasError = membership.hasError;
    final hasActivePaid = active != null && currentPlan?.isPaid == true;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: hasError
              ? colorScheme.error.withValues(alpha: 0.5)
              : hasActivePaid
              ? colorScheme.primary.withValues(alpha: 0.6)
              : colorScheme.outlineVariant,
          width: hasActivePaid ? 1.5 : 1.0,
        ),
      ),
      color: hasError
          ? colorScheme.errorContainer.withValues(alpha: isDark ? 0.25 : 0.4)
          : hasActivePaid
          ? (isDark
                ? colorScheme.surfaceContainerHigh
                : colorScheme.primaryContainer.withValues(alpha: 0.25))
          : (isDark
                ? colorScheme.surfaceContainer
                : colorScheme.surfaceContainerLow),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color:
                        (hasError
                                ? colorScheme.error
                                : hasActivePaid
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant)
                            .withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    hasError
                        ? Icons.error_outline_rounded
                        : hasActivePaid
                        ? Icons.verified_rounded
                        : Icons.shield_outlined,
                    color: hasError
                        ? colorScheme.error
                        : hasActivePaid
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MEMBRESÍA ACTUAL',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: hasActivePaid
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        membership.hasError
                            ? 'No se pudo consultar tu plan.'
                            : _describeMembership(active, currentPlan),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: hasError
                              ? colorScheme.error
                              : colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!hasError) ...[
              const SizedBox(height: 10),
              Text(
                active?.period == MembershipPeriod.lifetime
                    ? 'Beneficios de por vida activos sin fecha de caducidad.'
                    : active != null
                    ? 'Pago por periodo fijo. Al vencer, no habrá cargos automáticos.'
                    : 'Plan base incluido sin costo. Adquiere reservas anticipadas cuando lo requieras.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PeriodSelectorSection extends StatelessWidget {
  const _PeriodSelectorSection({
    required this.checkout,
    required this.controller,
  });

  final MembershipCheckoutState checkout;
  final MembershipCheckout controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                'Vigencia del beneficio',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Sin renovación automática',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<MembershipPeriod>(
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
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.isCurrent,
    required this.price,
    required this.period,
    required this.onPay,
  });

  final ServicePlan plan;
  final bool isCurrent;
  final int? price;
  final MembershipPeriod period;
  final VoidCallback? onPay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final amount = price;
    final priceLabel = !plan.isPaid
        ? 'Sin costo'
        : amount == null
        ? 'Precio no disponible'
        : formatMoney(amount);

    String? tierBadge;
    Color? tierBadgeBg;
    Color? tierBadgeFg;

    if (plan.id == 'campus_plus') {
      tierBadge = 'Popular';
      tierBadgeBg = isDark
          ? colorScheme.primaryContainer
          : colorScheme.primaryContainer.withValues(alpha: 0.6);
      tierBadgeFg = colorScheme.onPrimaryContainer;
    } else if (plan.id == 'campus_pro') {
      tierBadge = 'Máxima flexibilidad';
      tierBadgeBg = isDark
          ? colorScheme.tertiaryContainer
          : colorScheme.tertiaryContainer.withValues(alpha: 0.7);
      tierBadgeFg = colorScheme.onTertiaryContainer;
    }

    final cardBorder = isCurrent
        ? BorderSide(color: colorScheme.primary, width: 2)
        : plan.id == 'campus_plus'
        ? BorderSide(color: colorScheme.primary.withValues(alpha: 0.4))
        : BorderSide(
            color: colorScheme.outlineVariant.withValues(
              alpha: isDark ? 0.4 : 0.7,
            ),
          );

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: cardBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color:
                              (plan.isPaid
                                      ? colorScheme.primary
                                      : colorScheme.secondary)
                                  .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          plan.id == 'campus_pro'
                              ? Icons.workspace_premium_rounded
                              : plan.id == 'campus_plus'
                              ? Icons.stars_rounded
                              : Icons.coffee_rounded,
                          color: plan.isPaid
                              ? colorScheme.primary
                              : colorScheme.secondary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          plan.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (tierBadge != null && !isCurrent) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: tierBadgeBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tierBadge,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: tierBadgeFg,
                      ),
                    ),
                  ),
                ],
                if (isCurrent) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 14,
                          color: colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Tu plan actual',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(
              priceLabel,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: plan.isPaid
                    ? colorScheme.primary
                    : colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              !plan.isPaid
                  ? 'Plan básico permanente sin costo adicional'
                  : period == MembershipPeriod.lifetime
                  ? 'Pago único de por vida · Sin cobros recurrentes'
                  : 'Pago único por periodo · Sin renovación automática',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
            _FeatureRow(
              icon: Icons.check_circle_outline_rounded,
              text: 'Consulta, compra, seguimiento, QR y avisos: incluidos.',
              active: true,
            ),
            _FeatureRow(
              icon: plan.reservationsPerMonth > 0
                  ? Icons.schedule_rounded
                  : Icons.remove_circle_outline_rounded,
              text: plan.reservationsPerMonth == 0
                  ? 'Sin reservas de horario.'
                  : '${plan.reservationsPerMonth} reservas de horario al mes.',
              active: plan.reservationsPerMonth > 0,
            ),
            if (plan.maxLeadHours > 0)
              _FeatureRow(
                icon: Icons.timelapse_rounded,
                text:
                    'Reserva hasta ${plan.maxLeadHours} h antes de la recogida.',
                active: true,
              ),
            if (plan.id == 'campus_pro')
              const _FeatureRow(
                icon: Icons.delivery_dining_rounded,
                text: 'La cafetería lleva tu pedido hasta donde estés dentro del campus.',
              ),
            if (plan.isPaid && amount != null) ...[
              const SizedBox(height: 16),
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

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.text,
    this.active = true,
  });

  final IconData icon;
  final String text;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: active
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: active
                    ? colorScheme.onSurface
                    : colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentStatusBar extends StatelessWidget {
  const _PaymentStatusBar({required this.message, required this.isWorking});

  final String message;
  final bool isWorking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (isWorking) ...[
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
              ] else ...[
                Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ],
          ),
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
