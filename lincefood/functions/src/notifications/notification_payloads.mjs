export const notificationTopicKeys = Object.freeze([
  'cafeteria_menu',
  'cafeteria_ofertas',
  'cafeteria_consejos',
  'cafeteria_avisos',
]);

export function buildOrderMessage(copies, type, orderId, notificationId) {
  const copy = copies[type];
  return {
    notification: {
      title: copy.titulo,
      body: copy.cuerpo,
    },
    data: { type, ...(orderId == null ? {} : { orderId }) },
    android: {
      priority: 'high',
      notification: {
        channelId: 'avisos_cafeteria',
        ...(notificationId == null ? {} : { tag: notificationId }),
      },
    },
    apns: {
      headers: { 'apns-priority': '10' },
      payload: { aps: { sound: 'default' } },
    },
  };
}

export const buildOrderReadyMessage = (copies) =>
  buildOrderMessage(copies, 'pedido_listo');

export function buildTopicMessage(copies, topic, customText) {
  const copy = copies[topic];
  const body = customText ?? copy.cuerpo;
  return {
    topic,
    notification: {
      title: copy.titulo,
      body,
    },
    data: {
      type: topic,
      ...(customText == null ? {} : { customText }),
    },
  };
}
