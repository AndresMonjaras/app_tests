import assert from 'node:assert/strict';
import test from 'node:test';

import {
  transitionOrderForPayment,
  transitionPaymentRecord,
} from '../src/payment_transitions.mjs';

test('una transición exitosa marca pagado y la repetición no cambia nada', () => {
  const pending = { status: 'pendiente_pago', totalCents: 1200 };
  const paid = transitionOrderForPayment(pending, 'succeeded');

  assert.equal(paid.status, 'paid');
  assert.equal(transitionOrderForPayment(paid, 'succeeded'), null);
  assert.equal(transitionOrderForPayment(paid, 'failed'), null);
});

test('un pago fallido deja el pedido pendiente y conserva el motivo', () => {
  const updated = transitionOrderForPayment(
    { status: 'pendiente_pago' },
    'failed',
    'Tarjeta rechazada.',
  );
  assert.equal(updated.status, 'pendiente_pago');
  assert.equal(updated.paymentFailureReason, 'Tarjeta rechazada.');
});

test('eventos de pago repetidos no retroceden estados que ya avanzaron', () => {
  for (const status of [
    'paid',
    'confirmed',
    'preparing',
    'ready',
    'delivered',
    'incident',
  ]) {
    const order = { status };
    assert.equal(transitionOrderForPayment(order, 'succeeded'), null);
    assert.equal(
      transitionOrderForPayment(order, 'failed', 'Tarjeta rechazada.'),
      null,
    );
  }
});

test('un pago exitoso no puede volver a fallido', () => {
  const succeeded = transitionPaymentRecord(
    { status: 'requires_payment', paymentIntentId: 'pi-simulado' },
    'succeeded',
  );
  assert.equal(succeeded.status, 'succeeded');
  assert.equal(
    transitionPaymentRecord(succeeded, 'failed', {
      failureReason: 'Tarjeta rechazada.',
    }),
    null,
  );
});
