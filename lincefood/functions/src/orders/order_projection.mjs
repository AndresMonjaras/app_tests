import { customerOrderView, normalizeStoredStatus } from './order_status_rules.mjs';

// Un cobro o una confirmación pueden terminar de publicar sus índices después
// de que otra transacción rechazó el pedido. El estado terminal tiene prioridad.
export async function restoreRejectedTicket(database, orderId) {
  const order = (await database.ref('orders/' + orderId).get()).val();
  if (normalizeStoredStatus(order?.status) !== 'rejected') return;
  await database.ref().update({
    ['ordersByUser/' + order.ownerUid + '/' + orderId]: customerOrderView(order),
    ['staffQueue/' + orderId]: null,
  });
}
