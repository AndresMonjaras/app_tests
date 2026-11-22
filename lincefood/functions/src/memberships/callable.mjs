import { getDatabase } from 'firebase-admin/database';
import { defineSecret } from 'firebase-functions/params';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import Stripe from 'stripe';

import { AppError } from '../app_error.mjs';
import { createMembershipPaymentIntentHandler } from './membership_handlers.mjs';

const stripeSecretKey = defineSecret('STRIPE_SECRET_KEY');

export const createMembershipPaymentIntent = onCall(
  { region: 'us-central1', secrets: [stripeSecretKey] },
  async (request) => {
    const secretKey = stripeSecretKey.value();
    if (!/^(sk|rk)_test_/.test(secretKey)) {
      throw new HttpsError('failed-precondition', 'Los pagos de membresía requieren Stripe Sandbox.');
    }
    try {
      const handler = createMembershipPaymentIntentHandler({
        database: getDatabase(),
        stripe: new Stripe(secretKey),
      });
      return await handler(request);
    } catch (error) {
      if (error instanceof AppError) {
        throw new HttpsError(error.code, error.message);
      }
      throw new HttpsError('internal', 'No se pudo iniciar el pago. Inténtalo de nuevo.');
    }
  },
);
