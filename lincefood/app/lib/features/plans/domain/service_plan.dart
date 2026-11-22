import 'package:flutter/foundation.dart';

/// Plan de servicio de recogida. Los valores son de prueba y espejan
/// `functions/src/plans/service_plans.mjs`, que es la fuente de autoridad.
@immutable
class ServicePlan {
  const ServicePlan({
    required this.id,
    required this.name,
    required this.priceCentsPerMonth,
    required this.reservationsPerMonth,
    required this.maxLeadHours,
  });

  final String id;
  final String name;
  final int priceCentsPerMonth;
  final int reservationsPerMonth;
  final int maxLeadHours;

  bool get isPaid => priceCentsPerMonth > 0;
}

const servicePlans = <ServicePlan>[
  ServicePlan(
    id: 'basico',
    name: 'Básico',
    priceCentsPerMonth: 0,
    reservationsPerMonth: 0,
    maxLeadHours: 0,
  ),
  ServicePlan(
    id: 'campus_plus',
    name: 'Campus Plus',
    priceCentsPerMonth: 2900,
    reservationsPerMonth: 4,
    maxLeadHours: 24,
  ),
  ServicePlan(
    id: 'campus_pro',
    name: 'Campus Pro',
    priceCentsPerMonth: 4900,
    reservationsPerMonth: 8,
    maxLeadHours: 48,
  ),
];

/// Estado de la suscripción tal como lo escribe el servidor en `memberships/{uid}`.
/// El cliente solo lo muestra; nunca concede beneficios por su cuenta.
@immutable
class Membership {
  const Membership({
    required this.planId,
    required this.status,
    this.currentPeriodEnd,
    this.cancelAtPeriodEnd = false,
  });

  final String planId;
  final String status;
  final DateTime? currentPeriodEnd;
  final bool cancelAtPeriodEnd;

  /// Espejo de `hasActiveBenefits` del servidor.
  bool hasBenefits(DateTime now) {
    final activeStatus =
        status == 'active' || status == 'canceled_at_period_end';
    final end = currentPeriodEnd;
    return activeStatus && end != null && now.isBefore(end);
  }
}
