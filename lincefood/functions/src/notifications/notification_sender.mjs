import {
  getNotificationTokens,
  isInvalidNotificationToken,
  removeNotificationToken,
} from './notification_tokens.mjs';

const multicastLimit = 500;

export async function sendNotificationToUser({
  database,
  messaging,
  uid,
  message,
}) {
  const tokens = await getNotificationTokens(database, uid);
  let successCount = 0;

  for (let offset = 0; offset < tokens.length; offset += multicastLimit) {
    const batch = tokens.slice(offset, offset + multicastLimit);
    const response = await messaging.sendEachForMulticast({
      ...message,
      tokens: batch.map((entry) => entry.token),
    });
    successCount += response.successCount ?? 0;

    const removals = [];
    for (const [index, result] of (response.responses ?? []).entries()) {
      if (!result.success && isInvalidNotificationToken(result.error)) {
        removals.push(
          removeNotificationToken(database, uid, batch[index].hash),
        );
      }
    }
    await Promise.all(removals);
  }

  return { successCount };
}
