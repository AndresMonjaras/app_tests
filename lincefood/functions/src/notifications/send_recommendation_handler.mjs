import { AppError } from '../app_error.mjs';
import {
  createBroadcastNotificationId,
  saveTopicNotificationToInboxes,
} from './notification_inbox.mjs';

const emojiPattern = /[\p{Extended_Pictographic}\p{Regional_Indicator}\uFE0F\u20E3]/u;
const emailPattern = /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i;
const phonePattern = /\+?\d[\d\s().-]{8,}\d/u;
const identifierPattern = /\b[A-Z]{4}\d{6}[A-Z0-9]{8,10}\b|\b[A-Z&Ñ]{3,4}\d{6}[A-Z0-9]{3}\b/i;

function validateRecommendation(request) {
  if (typeof request.auth?.uid !== 'string' || request.auth.uid.length === 0) {
    throw new AppError('unauthenticated', 'Inicia sesión para continuar.');
  }
  if (
    request.auth.token?.staff !== true &&
    request.auth.token?.admin !== true
  ) {
    throw new AppError(
      'permission-denied',
      'Solo el personal puede enviar recomendaciones.',
    );
  }

  const text = request.data?.text;
  if (typeof text !== 'string') {
    throw new AppError('invalid-argument', 'La recomendación no es válida.');
  }
  const recommendation = text.trim();
  if (recommendation.length === 0 || Array.from(recommendation).length > 120) {
    throw new AppError(
      'invalid-argument',
      'La recomendación debe tener entre 1 y 120 caracteres.',
    );
  }
  if (emojiPattern.test(recommendation)) {
    throw new AppError(
      'invalid-argument',
      'La recomendación no puede incluir emojis.',
    );
  }
  if (
    emailPattern.test(recommendation) ||
    phonePattern.test(recommendation) ||
    identifierPattern.test(recommendation)
  ) {
    throw new AppError(
      'invalid-argument',
      'La recomendación no puede incluir datos personales.',
    );
  }
  return recommendation;
}

export function createSendRecommendationHandler({
  database,
  messaging,
  loadCopies,
}) {
  return async (request) => {
    const text = validateRecommendation(request);
    const copies = await loadCopies();
    const message = {
      topic: 'cafeteria_ofertas',
      notification: {
        title: copies.cafeteria_ofertas.titulo,
        body: text,
      },
      data: { type: 'cafeteria_ofertas' },
    };
    const inboxCount = await saveTopicNotificationToInboxes({
      database,
      topic: 'cafeteria_ofertas',
      notificationId: createBroadcastNotificationId(),
      message,
    });
    await messaging.send(message);
    return { sent: true, inboxCount };
  };
}
