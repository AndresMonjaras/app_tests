import { randomUUID } from 'node:crypto';
import { AppError } from '../app_error.mjs';

export function callerUid(request) {
  const uid = request.auth?.uid;
  if (!uid) throw new AppError('unauthenticated', 'Inicia sesión para continuar.');
  return uid;
}

export async function requireAdmin(auth, request) {
  const uid = callerUid(request);
  if (request.auth.token?.admin !== true) {
    throw new AppError('permission-denied', 'Solo administración puede realizar esta operación.');
  }
  const user = await findUser(() => auth.getUser(uid));
  if (user.disabled || user.customClaims?.admin !== true) {
    throw new AppError('permission-denied', 'El permiso de administración ya no está activo.');
  }
  return uid;
}

export async function findUser(lookup) {
  try {
    return await lookup();
  } catch (error) {
    if (error.code === 'auth/user-not-found') {
      throw new AppError('not-found', 'No se encontró la cuenta.');
    }
    throw error;
  }
}

export function requireKey(value) {
  if (typeof value !== 'string' || value.length < 1 || value.length > 128 ||
      /[.#$\/\[\]\x00-\x1f\x7f]/.test(value)) {
    throw new AppError('invalid-argument', 'El identificador no es válido.');
  }
  return value;
}

export async function findTargetUser(auth, { uid, email } = {}) {
  if (email === undefined && typeof uid === 'string' && uid.length >= 1 && uid.length <= 128) {
    return findUser(() => auth.getUser(uid));
  }
  if (uid === undefined && typeof email === 'string') {
    const address = email.trim();
    if (address.length <= 254 && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(address)) {
      return findUser(() => auth.getUserByEmail(address));
    }
  }
  throw new AppError('invalid-argument', 'Indica un UID o correo válido.');
}

export async function requireAnotherAdmin(auth, excludedUid) {
  let pageToken;
  do {
    const page = await auth.listUsers(1000, pageToken);
    if (page.users.some((user) =>
      user.uid !== excludedUid && !user.disabled && user.customClaims?.admin === true)) {
      return;
    }
    pageToken = page.pageToken;
  } while (pageToken);
  throw new AppError('failed-precondition', 'Debe quedar al menos una cuenta administrativa activa.');
}

export async function withAdminWrite(database, action) {
  const lock = database.ref('adminWriteLock');
  const owner = randomUUID();
  const initialized = lock.child('initialized');
  // El nodo persiste para que un null de caché nunca adquiera el bloqueo.
  if (!(await initialized.get()).exists()) await initialized.set(true);
  const expiresAt = Date.now() + 180_000;
  const result = await lock.transaction((current) => {
    if (current === null) return null;
    if (current.owner && current.expiresAt > Date.now()) return undefined;
    return { initialized: true, owner, expiresAt };
  });
  if (!result.committed || !result.snapshot.exists() || result.snapshot.val().owner !== owner) {
    throw new AppError('aborted', 'Hay otro cambio administrativo en curso. Inténtalo de nuevo.');
  }

  try {
    return await action();
  } finally {
    try {
      const released = await lock.transaction((current) => {
        if (current === null) return null;
        return current.owner === owner ? { initialized: true } : undefined;
      });
      if (released.committed && !released.snapshot.exists()) {
        await initialized.set(true);
      }
    } catch {
      // El bloqueo caduca si no se pudo liberar.
    }
  }
}

export function createAudit({ database, serverTimestamp }, actorUid, action, target, before, after) {
  const ref = database.ref('adminAudit').push();
  const record = {
    actorUid,
    action,
    target,
    before: before ?? { exists: false },
    after: after ?? { exists: false },
    at: serverTimestamp(),
  };
  return { ref, record };
}

export async function auditAuthChange(deps, actorUid, action, target, before, after, change) {
  const { ref, record } = createAudit(deps, actorUid, action, target, before, after);
  // Registra el intento antes de cruzar de RTDB a Firebase Auth.
  await ref.set({ ...record, after: { pending: true } });
  await change();
  try {
    await ref.set(record);
  } catch {
    await ref.set(record);
  }
}
