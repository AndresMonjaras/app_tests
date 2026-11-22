import assert from 'node:assert/strict';
import test from 'node:test';

import {
  canReservePickup,
  consumeReservation,
  getServicePlan,
  hasActiveBenefits,
  remainingReservations,
  transitionSubscription,
} from '../src/plans/service_plans.mjs';

const MAY = new Date('2026-05-10T12:00:00Z');
const JUNE = new Date('2026-06-02T12:00:00Z');

test('solo existen los tres planes con precios y límites de prueba', () => {
  assert.equal(getServicePlan('basico').priceCentsPerMonth, 0);
  assert.equal(getServicePlan('campus_plus').priceCentsPerMonth, 2900);
  assert.equal(getServicePlan('campus_pro').priceCentsPerMonth, 4900);
  assert.equal(getServicePlan('campus_pro').reservationsPerMonth, 8);
  assert.equal(getServicePlan('campus_plus').maxLeadHours, 24);
  assert.throws(() => getServicePlan('__proto__'), { code: 'invalid-argument' });
  assert.throws(() => getServicePlan('premium'), { code: 'invalid-argument' });
});

test('el cupo se consume hasta agotarse y se reinicia al cambiar de mes', () => {
  const plan = getServicePlan('campus_plus');
  let usage = null;
  for (let i = 0; i < 4; i += 1) {
    usage = consumeReservation(plan, usage, MAY);
  }
  assert.equal(remainingReservations(plan, usage, MAY), 0);
  assert.throws(() => consumeReservation(plan, usage, MAY), {
    code: 'resource-exhausted',
  });
  assert.equal(remainingReservations(plan, usage, JUNE), 4);
  assert.deepEqual(consumeReservation(plan, usage, JUNE), {
    period: '2026-06',
    used: 1,
  });
});

test('el plan básico no tiene reservas', () => {
  const basic = getServicePlan('basico');
  assert.equal(remainingReservations(basic, null, MAY), 0);
  assert.equal(
    canReservePickup(basic, new Date(MAY.getTime() + 3_600_000), MAY),
    false,
  );
});

test('la anticipación respeta el máximo del plan', () => {
  const plus = getServicePlan('campus_plus');
  const pro = getServicePlan('campus_pro');
  const in30h = new Date(MAY.getTime() + 30 * 3_600_000);
  assert.equal(canReservePickup(plus, in30h, MAY), false);
  assert.equal(canReservePickup(pro, in30h, MAY), true);
  assert.equal(canReservePickup(pro, new Date(MAY.getTime() - 1), MAY), false);
});

test('solo un pago confirmado activa la suscripción', () => {
  const active = transitionSubscription(
    { status: 'none' },
    { type: 'invoice.paid', currentPeriodEnd: '2026-06-10T00:00:00Z' },
    MAY,
  );
  assert.equal(active.status, 'active');
  assert.equal(
    transitionSubscription(active, { type: 'invoice.paid' }, MAY),
    null,
  );
  assert.equal(transitionSubscription({ status: 'none' }, { type: 'checkout.started' }, MAY), null);
});

test('un pago fallido deja la suscripción sin beneficios', () => {
  const failed = transitionSubscription(
    { status: 'active', currentPeriodEnd: '2026-06-10T00:00:00Z' },
    { type: 'invoice.payment_failed' },
    MAY,
  );
  assert.equal(failed.status, 'past_due');
  const sub = { ...failed };
  assert.equal(hasActiveBenefits(sub, MAY), false);
});

test('cancelar la renovación conserva beneficios hasta el fin del periodo', () => {
  const active = {
    status: 'active',
    cancelAtPeriodEnd: false,
    currentPeriodEnd: '2026-06-01T00:00:00Z',
  };
  const canceling = transitionSubscription(
    active,
    { type: 'customer.subscription.updated', cancelAtPeriodEnd: true },
    MAY,
  );
  assert.equal(canceling.status, 'canceled_at_period_end');
  assert.equal(hasActiveBenefits(canceling, MAY), true);

  const ended = transitionSubscription(canceling, { type: 'period.check' }, JUNE);
  assert.equal(ended.status, 'canceled');
  assert.equal(hasActiveBenefits(ended, JUNE), false);
});

test('eliminar la suscripción en Stripe la cancela de inmediato', () => {
  const deleted = transitionSubscription(
    { status: 'active', currentPeriodEnd: '2026-06-10T00:00:00Z' },
    { type: 'customer.subscription.deleted' },
    MAY,
  );
  assert.equal(deleted.status, 'canceled');
  assert.equal(hasActiveBenefits(deleted, MAY), false);
  assert.equal(
    transitionSubscription(deleted, { type: 'customer.subscription.deleted' }, MAY),
    null,
  );
});
