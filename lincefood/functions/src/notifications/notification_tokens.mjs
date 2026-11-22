const invalidTokenCodes = new Set([
  'messaging/invalid-registration-token',
  'messaging/registration-token-not-registered',
]);

export function isInvalidNotificationToken(error) {
  return invalidTokenCodes.has(error?.code);
}

export async function getNotificationTokens(database, uid) {
  const snapshot = await database.ref(`notificationTokens/${uid}`).get();
  const value = snapshot.val();
  if (!value || typeof value !== 'object' || Array.isArray(value)) return [];

  return Object.entries(value).flatMap(([hash, record]) => {
    const token = record?.token;
    return typeof token === 'string' && token.length > 0
      ? [{ hash, token }]
      : [];
  });
}

export function removeNotificationToken(database, uid, hash) {
  return database.ref(`notificationTokens/${uid}/${hash}`).remove();
}
