import { AppError } from '../app_error.mjs';
import { buildTopicMessage, notificationTopicKeys } from './notification_payloads.mjs';
import {
  createBroadcastNotificationId,
  saveTopicNotificationToInboxes,
} from './notification_inbox.mjs';

const emailPattern = /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i;
const phonePattern = /\+?\d[\d\s().-]{8,}\d/u;
const identifierPattern = /\b[A-Z]{4}\d{6}[A-Z0-9]{8,10}\b|\b[A-Z&Ñ]{3,4}\d{6}[A-Z0-9]{3}\b/i;
const emojiPattern = /[\p{Extended_Pictographic}\p{Regional_Indicator}\uFE0F\u20E3]/u;

function requireStaff(request) {
  if (typeof request.auth?.uid !== 'string' || request.auth.uid.length === 0) {
    throw new AppError('unauthenticated', 'Inicia sesión para continuar.');
  }
  if (
    request.auth.token?.admin !== true &&
    request.auth.token?.staff !== true
  ) {
    throw new AppError(
      'permission-denied',
      'Solo el personal autorizado puede enviar avisos.',
    );
  }
  return request.auth.token?.admin === true;
}

function validateCustomText(topic, customText, isAdmin) {
  if (customText == null) return undefined;
  if (!isAdmin) {
    throw new AppError(
      'permission-denied',
      'Solo una persona administradora puede escribir el aviso.',
    );
  }
  if (topic !== 'cafeteria_avisos' || typeof customText !== 'string') {
    throw new AppError(
      'invalid-argument',
      'El texto personalizado solo se permite para los avisos.',
    );
  }

  const text = customText.trim();
  if (text.length === 0 || Array.from(text).length > 120) {
    throw new AppError(
      'invalid-argument',
      'El aviso debe tener entre 1 y 120 caracteres.',
    );
  }
  if (emojiPattern.test(text)) {
    throw new AppError('invalid-argument', 'El aviso no puede incluir emojis.');
  }
  if (
    emailPattern.test(text) ||
    phonePattern.test(text) ||
    identifierPattern.test(text)
  ) {
    throw new AppError(
      'invalid-argument',
      'El aviso no puede incluir datos personales.',
    );
  }
  return text;
}

export function createSendTopicNotificationHandler({
  database,
  messaging,
  loadCopies,
}) {
  return async (request) => {
    const isAdmin = requireStaff(request);

    const topic = request.data?.topic;
    if (!notificationTopicKeys.includes(topic)) {
      throw new AppError('invalid-argument', 'El tema de aviso no es válido.');
    }

    const customText = validateCustomText(
      topic,
      request.data?.customText,
      isAdmin,
    );
    const copies = await loadCopies();
    const message = buildTopicMessage(copies, topic, customText);
    const inboxCount = await saveTopicNotificationToInboxes({
      database,
      topic,
      notificationId: createBroadcastNotificationId(),
      message,
    });
    await messaging.send(message);
    return { sent: true, inboxCount };
  };
}
