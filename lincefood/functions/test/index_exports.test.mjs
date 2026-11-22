import assert from 'node:assert/strict';
import { test } from 'node:test';

test('el punto de entrada inicializa Firebase y exporta los módulos existentes', async () => {
  const functions = await import('../index.mjs');

  for (const name of [
    'createOrder',
    'cancelOrder',
    'rejectOrder',
    'createPaymentIntent',
    'notifyOrderStatus',
    'sendRecommendation',
    'sendTopicNotification',
    'upsertProduct',
    'updateProductPrice',
    'setProductAvailability',
    'deleteProduct',
    'setStaffRole',
    'setAdminRole',
  ]) {
    assert.ok(functions[name], `Falta exportar ${name}.`);
  }
});
