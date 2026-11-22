import { AppError } from '../app_error.mjs';
import { getServicePlan } from '../plans/service_plans.mjs';

const daysByPeriod = { weekly: 7, monthly: 30, lifetime: null };
const dayMs = 86_400_000;
const currency = 'mxn';
const keyPattern = /^[A-Za-z0-9_-]{1,128}$/;

function isPaidPlan(planId) {
  return planId === 'campus_plus' || planId === 'campus_pro';
}

function isValidKey(value) {
  return typeof value === 'string' && keyPattern.test(value);
}

function isValidPeriod(period) {
  return typeof period === 'string' && Object.hasOwn(daysByPeriod, period);
}

function isLifetime(membership) {
  return membership?.status === 'active' &&
    membership.period === 'lifetime' &&
    isPaidPlan(membership.planId);
}

function preservesLifetime(current, planId, period) {
  return isLifetime(current) &&
    (period !== 'lifetime' ||
      getServicePlan(current.planId).reservationsPerMonth >=
        getServicePlan(planId).reservationsPerMonth);
}

async function transactionWithInitialNode(ref, update) {
  const apply = (current) => current == null ? null : update(current);
  let result = await ref.transaction(apply);
  if (!result.snapshot.exists()) {
    // Un hijo provisional permite iniciar la transacción sin sobrescribir datos.
    await ref.child('_initialized').set(true);
    result = await ref.transaction(apply);
  }
  if (!result.snapshot.exists()) {
    throw new Error('La transacción no encontró el registro de membresía.');
  }
  return result.snapshot.val();
}

export function createMembershipPaymentIntentHandler({
  database,
  stripe,
  now = Date.now,
}) {
  return async (request) => {
    const uid = request.auth?.uid;
    if (!isValidKey(uid)) {
      throw new AppError('unauthenticated', 'Inicia sesión para continuar.');
    }
    const { planId, period } = request.data ?? {};
    if (!isPaidPlan(planId) || !isValidPeriod(period)) {
      throw new AppError('invalid-argument', 'Elige un plan y una modalidad válidos.');
    }

    const [priceSnapshot, membershipSnapshot] = await Promise.all([
      database.ref(`membershipPlans/${planId}/prices/${period}`).get(),
      database.ref(`memberships/${uid}`).get(),
    ]);
    const amount = priceSnapshot.val();
    if (!Number.isSafeInteger(amount) || amount <= 0 || amount > 99_999_999) {
      throw new AppError('failed-precondition', 'El precio de esta modalidad no está disponible.');
    }
    if (preservesLifetime(membershipSnapshot.val(), planId, period)) {
      throw new AppError('failed-precondition', 'Ya tienes un plan de por vida.');
    }

    const day = new Date(now()).toISOString().slice(0, 10);
    const intent = await stripe.paymentIntents.create({
      amount,
      currency,
      metadata: { type: 'membership', uid, planId, period },
      automatic_payment_methods: { enabled: true },
    }, { idempotencyKey: `membership:${uid}:${planId}:${period}:${day}` });

    if (intent.livemode !== false) {
      throw new AppError('failed-precondition', 'Los pagos de membresía requieren Stripe Sandbox.');
    }
    if (intent.status === 'succeeded' || intent.status === 'processing') {
      throw new AppError('already-exists', 'Este pago ya se inició. Revisa el estado de tu plan.');
    }
    if (intent.status === 'canceled' || !intent.client_secret || !isValidKey(intent.id)) {
      throw new AppError('failed-precondition', 'El pago ya no está disponible. Inténtalo mañana.');
    }

    const payment = { uid, planId, period, amount, currency };
    const saved = await transactionWithInitialNode(
      database.ref(`membershipPayments/${uid}/${intent.id}`),
      (current) => current.status ? undefined : { ...payment, status: 'requires_payment' },
    );
    if (saved.status !== 'requires_payment') {
      throw new AppError('already-exists', 'Este pago ya se inició. Revisa el estado de tu plan.');
    }

    return { clientSecret: intent.client_secret, paymentIntentId: intent.id };
  };
}

export async function activateMembershipFromPayment(database, intent, now = Date.now()) {
  const { uid, planId, period } = intent?.metadata ?? {};
  const id = intent?.id;
  if (intent?.livemode !== false || intent.metadata?.type !== 'membership' ||
      !isValidKey(uid) || !isValidKey(id) || !isPaidPlan(planId) || !isValidPeriod(period)) {
    return false;
  }

  const paymentRef = database.ref(`membershipPayments/${uid}/${id}`);
  const payment = (await paymentRef.get()).val();
  if (!payment || payment.uid !== uid || payment.planId !== planId ||
      payment.period !== period || intent.currency !== currency ||
      payment.currency !== currency ||
      !Number.isSafeInteger(payment.amount) || payment.amount <= 0 ||
      payment.amount !== intent.amount || payment.amount !== intent.amount_received) {
    return false;
  }
  if (payment.status === 'succeeded') return true;
  if (payment.status !== 'requires_payment') return false;

  const membership = await transactionWithInitialNode(
    database.ref(`memberships/${uid}`),
    (current) => {
      if (Object.hasOwn(current.appliedPayments ?? {}, id)) return undefined;
      const appliedPayments = { ...current.appliedPayments, [id]: true };
      if (preservesLifetime(current, planId, period)) {
        return { ...current, appliedPayments };
      }

      const previousEnd = current.expiresAt ?? Date.parse(current.currentPeriodEnd);
      const samePlan = current.planId === planId;
      const active = current.status === 'active' || current.status === 'canceled_at_period_end';
      const extending = samePlan && active && Number.isFinite(previousEnd) && previousEnd > now;
      const periodStart = extending ? previousEnd : now;
      return {
        planId,
        period,
        startsAt: extending ? current.startsAt ?? now : now,
        expiresAt: period === 'lifetime' ? null : periodStart + daysByPeriod[period] * dayMs,
        status: 'active',
        paymentIntentId: id,
        appliedPayments,
      };
    },
  );
  if (!Object.hasOwn(membership.appliedPayments ?? {}, id)) {
    throw new Error('No se pudo confirmar la activación de la membresía.');
  }

  const result = await paymentRef.transaction((current) => {
    if (current == null) return null;
    if (current.status !== 'requires_payment') return undefined;
    return { ...current, status: 'succeeded' };
  });
  if (!result.snapshot.exists() || result.snapshot.val().status !== 'succeeded') {
    throw new Error('No se pudo confirmar el registro del pago.');
  }
  return true;
}
