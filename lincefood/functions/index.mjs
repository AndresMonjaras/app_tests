import { initializeApp } from 'firebase-admin/app';
import { getDatabase, ServerValue } from 'firebase-admin/database';
import { HttpsError, onCall, onRequest } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';
import Stripe from 'stripe';

import { AppError } from './src/app_error.mjs';
import {
  createCreateOrderHandler,
  createCreatePaymentIntentHandler,
  createStripeWebhookHandler,
} from './src/handlers.mjs';
import { createRejectOrderHandler } from './src/orders/reject_order_handler.mjs';
import { createCancelOrderHandler } from './src/orders/cancel_order_handler.mjs';
import {
  requirePickupQr,
  createConsumePickupTokenHandler,
  createIssuePickupTokenHandler,
} from './src/pickup/pickup_handlers.mjs';

const region = 'us-central1';
const stripeSecretKey = defineSecret('STRIPE_SECRET_KEY');
const stripeWebhookSecret = defineSecret('STRIPE_WEBHOOK_SECRET');

initializeApp({
  projectId: 'lincefood-app',
  databaseURL: 'https://lincefood-app-default-rtdb.firebaseio.com',
});
const database = getDatabase();

function withCallableErrors(handler) {
  return async (request) => {
    try {
      return await handler(request);
    } catch (error) {
      if (error instanceof AppError) {
        throw new HttpsError(error.code, error.message);
      }
      throw new HttpsError(
        'internal',
        'No se pudo completar la operación. Inténtalo de nuevo.',
      );
    }
  };
}

export const createOrder = onCall(
  { region },
  withCallableErrors(
    createCreateOrderHandler({
      database,
      serverTimestamp: () => ServerValue.TIMESTAMP,
    }),
  ),
);

export const cancelOrder = onCall(
  { region, secrets: [stripeSecretKey] },
  withCallableErrors(async (request) => {
    const handler = createCancelOrderHandler({
      database,
      stripe: new Stripe(stripeSecretKey.value()),
    });
    return handler(request);
  }),
);

export const rejectOrder = onCall(
  { region, secrets: [stripeSecretKey] },
  withCallableErrors(async (request) => {
    const handler = createRejectOrderHandler({
      database,
      stripe: new Stripe(stripeSecretKey.value()),
    });
    return handler(request);
  }),
);

export const createPaymentIntent = onCall(
  { region, secrets: [stripeSecretKey] },
  withCallableErrors(async (request) => {
    const handler = createCreatePaymentIntentHandler({
      database,
      stripe: new Stripe(stripeSecretKey.value()),
    });
    return handler(request);
  }),
);

export const stripeWebhook = onRequest(
  { region, secrets: [stripeSecretKey, stripeWebhookSecret] },
  async (request, response) => {
    const handler = createStripeWebhookHandler({
      database,
      stripe: new Stripe(stripeSecretKey.value()),
      webhookSecret: stripeWebhookSecret.value(),
    });
    return handler(request, response);
  },
);

export const issuePickupToken = onCall(
  { region },
  withCallableErrors(
    createIssuePickupTokenHandler({ database }),
  ),
);

export const consumePickupToken = onCall(
  { region },
  withCallableErrors(
    createConsumePickupTokenHandler({ database }),
  ),
);

export const consumePickupFolio = onCall(
  { region },
  withCallableErrors(requirePickupQr),
);

export { updateOrderStatus } from './src/orders/update_order_status.mjs';
export { resolveOrderIncident } from './src/orders/resolve_order_incident.mjs';
export {
  upsertProduct,
  updateProductPrice,
  setProductAvailability,
  deleteProduct,
} from './src/catalog/index.mjs';
export { setStaffRole, setAdminRole } from './src/roles/index.mjs';
export {
  notifyOrderStatus,
  sendRecommendation,
  sendTopicNotification,
} from './src/notifications/index.mjs';
export { createMembershipPaymentIntent } from './src/memberships/callable.mjs';
