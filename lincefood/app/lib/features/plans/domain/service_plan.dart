import 'package:flutter/foundation.dart';

/// Beneficios de recogida de cada plan. Los precios se leen de RTDB.
@immutable
class ServicePlan {
  const ServicePlan({
    required this.id,
    required this.name,
    required this.reservationsPerMonth,
    required this.maxLeadHours,
  });

  final String id;
  final String name;
  final int reservationsPerMonth;
  final int maxLeadHours;

  bool get isPaid => id != 'basico';
}

const servicePlans = <ServicePlan>[
  ServicePlan(
    id: 'basico',
    name: 'Básico',
    reservationsPerMonth: 0,
    maxLeadHours: 0,
  ),
  ServicePlan(
    id: 'campus_plus',
    name: 'Campus Plus',
    reservationsPerMonth: 4,
    maxLeadHours: 24,
  ),
  ServicePlan(
    id: 'campus_pro',
    name: 'Campus Pro',
    reservationsPerMonth: 8,
    maxLeadHours: 48,
  ),
];

enum MembershipPeriod {
  weekly('Semanal'),
  monthly('Mensual'),
  lifetime('De por vida');

  const MembershipPeriod(this.label);

  final String label;
}

@immutable
class MembershipPrices {
  const MembershipPrices({required this.amounts, required this.demo});

  final Map<MembershipPeriod, int> amounts;
  final bool demo;
}

/// Estado de la suscripción tal como lo escribe el servidor en `memberships/{uid}`.
/// El cliente solo lo muestra; nunca concede beneficios por su cuenta.
@immutable
class Membership {
  const Membership({
    required this.planId,
    required this.status,
    this.period,
    this.currentPeriodEnd,
    this.cancelAtPeriodEnd = false,
    this.appliedPayments = const {},
  });

  final String planId;
  final String status;
  final MembershipPeriod? period;
  final DateTime? currentPeriodEnd;
  final bool cancelAtPeriodEnd;
  final Set<String> appliedPayments;

  bool hasBenefits(DateTime now) {
    final activeStatus =
        status == 'active' || status == 'canceled_at_period_end';
    final end = currentPeriodEnd;
    return activeStatus &&
        (period == MembershipPeriod.lifetime ||
            (end != null && now.isBefore(end)));
  }
}
