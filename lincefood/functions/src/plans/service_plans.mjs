import { AppError } from '../app_error.mjs';

// Precios de prueba en centavos MXN. No son tarifas reales.
export const SERVICE_PLANS = Object.freeze({
  basico: Object.freeze({
    id: 'basico',
    name: 'Básico',
    priceCentsPerMonth: 0,
    reservationsPerMonth: 0,
    maxLeadHours: 0,
  }),
  campus_plus: Object.freeze({
    id: 'campus_plus',
    name: 'Campus Plus',
    priceCentsPerMonth: 2900,
    reservationsPerMonth: 4,
    maxLeadHours: 24,
  }),
  campus_pro: Object.freeze({
    id: 'campus_pro',
    name: 'Campus Pro',
    priceCentsPerMonth: 4900,
    reservationsPerMonth: 8,
    maxLeadHours: 48,
  }),
});

// Estados que conceden beneficios. Solo se llega a ellos por eventos confirmados.
const BENEFIT_STATUSES = new Set(['active', 'canceled_at_period_end']);

export function getServicePlan(planId) {
  const plan = Object.hasOwn(SERVICE_PLANS, planId)
    ? SERVICE_PLANS[planId]
    : null;
  if (!plan) {
    throw new AppError('invalid-argument', 'Plan de servicio no válido.');
  }
  return plan;
}

/** Periodo mensual en formato AAAA-MM, en UTC. */
export function periodKeyFor(date) {
  const year = date.getUTCFullYear();
  const month = String(date.getUTCMonth() + 1).padStart(2, '0');
  return `${year}-${month}`;
}

/** Reservas que aún puede usar el plan en el periodo indicado. */
export function remainingReservations(plan, usage, now) {
  const period = periodKeyFor(now);
  const used = usage?.period === period ? usage.used : 0;
  return Math.max(0, plan.reservationsPerMonth - used);
}

/**
 * Consume una reserva del cupo mensual. Devuelve el nuevo uso;
 * lanza error si no quedan cupos. Reinicia el conteo al cambiar de periodo.
 */
export function consumeReservation(plan, usage, now) {
  if (remainingReservations(plan, usage, now) <= 0) {
    throw new AppError(
      'resource-exhausted',
      'No quedan reservas en tu plan para este mes.',
    );
  }
  const period = periodKeyFor(now);
  const used = usage?.period === period ? usage.used : 0;
  return { period, used: used + 1 };
}

/**
 * Una reserva es válida si el plan incluye reservas, la recogida es futura
 * y está dentro de la anticipación máxima del plan.
 */
export function canReservePickup(plan, pickupAt, now) {
  if (plan.reservationsPerMonth <= 0) return false;
  const hoursAhead = (pickupAt.getTime() - now.getTime()) / 3_600_000;
  return hoursAhead > 0 && hoursAhead <= plan.maxLeadHours;
}

/**
 * Transición de la suscripción según un evento confirmado de Stripe
 * (o de expiración calculada por el servidor). Devuelve la nueva suscripción
 * o null si el evento no cambia nada.
 */
export function transitionSubscription(subscription, event, now) {
  const current = subscription ?? { status: 'none' };

  switch (event?.type) {
    case 'invoice.paid':
      if (current.status === 'active') return null;
      return {
        ...current,
        status: 'active',
        currentPeriodEnd: event.currentPeriodEnd,
        cancelAtPeriodEnd: false,
      };

    case 'invoice.payment_failed':
      if (current.status === 'past_due') return null;
      return { ...current, status: 'past_due' };

    case 'customer.subscription.updated': {
      const cancel = event.cancelAtPeriodEnd === true;
      if (BENEFIT_STATUSES.has(current.status) === false) return null;
      if (current.cancelAtPeriodEnd === cancel) return null;
      return {
        ...current,
        status: cancel ? 'canceled_at_period_end' : 'active',
        cancelAtPeriodEnd: cancel,
      };
    }

    case 'customer.subscription.deleted':
      if (current.status === 'canceled') return null;
      return { ...current, status: 'canceled', cancelAtPeriodEnd: false };

    case 'period.check':
      if (current.status !== 'canceled_at_period_end') return null;
      if (!current.currentPeriodEnd || now < new Date(current.currentPeriodEnd)) {
        return null;
      }
      return { ...current, status: 'canceled' };

    default:
      return null;
  }
}

/** Solo una suscripción activa o cancelada al final del periodo vigente da beneficios. */
export function hasActiveBenefits(subscription, now) {
  if (!subscription || !BENEFIT_STATUSES.has(subscription.status)) return false;
  if (!subscription.currentPeriodEnd) return false;
  return now < new Date(subscription.currentPeriodEnd);
}
