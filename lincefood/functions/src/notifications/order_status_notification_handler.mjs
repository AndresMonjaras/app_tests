import { buildOrderMessage } from './notification_payloads.mjs';
import { sendNotificationToUser } from './notification_sender.mjs';
import {
  orderNotificationId,
  recordOrderPushFailure,
  saveNotificationToInbox,
} from './notification_inbox.mjs';

const statusAliases = new Map([
  ['pagado', 'paid'],
  ['paid', 'paid'],
  ['confirmado', 'confirmed'],
  ['confirmed', 'confirmed'],
  ['rechazado', 'rejected'],
  ['rejected', 'rejected'],
  ['preparando', 'preparing'],
  ['en cocina', 'preparing'],
  ['preparing', 'preparing'],
  ['listo', 'ready'],
  ['listo para recoger', 'ready'],
  ['ready', 'ready'],
  ['entregado', 'delivered'],
  ['delivered', 'delivered'],
]);

const noticeForStatus = new Map([
  ['paid', 'pedido_registrado'],
  ['confirmed', 'pedido_confirmado'],
  ['rejected', 'pedido_rechazado'],
  ['preparing', 'pedido_en_cocina'],
  ['ready', 'pedido_listo'],
  ['delivered', 'pedido_entregado'],
]);

function normalizeStatus(order) {
  const value = order?.status ?? order?.estado;
  return typeof value === 'string'
    ? statusAliases.get(value.trim().toLowerCase())
    : undefined;
}

export function createOrderStatusNotificationHandler({
  database,
  messaging,
  loadCopies,
}) {
  return async (event) => {
    const before = event.data?.before?.val();
    const after = event.data?.after?.val();
    if (!after || typeof after !== 'object') return;

    const nextStatus = normalizeStatus(after);
    const noticeType = noticeForStatus.get(nextStatus);
    if (!noticeType || normalizeStatus(before) === nextStatus) return;

    const orderId = event.params?.orderId;
    if (typeof orderId !== 'string' || orderId.length === 0) return;
    const uid = after.ownerUid;
    if (typeof uid !== 'string' || uid.length === 0) return;

    const copies = await loadCopies();
    const notificationId = orderNotificationId(orderId, noticeType);
    const message = buildOrderMessage(
      copies,
      noticeType,
      orderId,
      notificationId,
      nextStatus === 'rejected' ? after.rejectionReason : undefined,
    );
    const shouldSend = await saveNotificationToInbox({
      database,
      uid,
      notificationId,
      type: noticeType,
      title: message.notification.title,
      body: message.notification.body,
      orderId,
    });
    if (!shouldSend) return { successCount: 0, deduplicated: true };

    try {
      return await sendNotificationToUser({
        database,
        messaging,
        uid,
        message,
      });
    } catch (error) {
      await recordOrderPushFailure(database, uid, notificationId, noticeType);
      throw error;
    }
  };
}
