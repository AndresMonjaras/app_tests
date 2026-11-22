import { AppError } from '../app_error.mjs';

function requireUid(value) {
  if (typeof value !== 'string' || value.length === 0) {
    throw new AppError('unauthenticated', 'Inicia sesión para continuar.');
  }
  return value;
}

function requireTargetUid(value) {
  if (typeof value !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(value)) {
    throw new AppError('invalid-argument', 'La cuenta no es válida.');
  }
  return value;
}

function requireAdmin(request) {
  requireUid(request.auth?.uid);
  if (request.auth.token?.admin !== true) {
    throw new AppError('permission-denied', 'Solo administración puede asignar roles.');
  }
}

async function updateClaim(auth, uid, claim, enabled) {
  const user = await auth.getUser(uid);
  const claims = { ...(user.customClaims ?? {}) };
  if (enabled) {
    claims[claim] = true;
  } else {
    delete claims[claim];
  }
  await auth.setCustomUserClaims(uid, claims);
  return { uid, [claim]: enabled };
}

export function createSetStaffRoleHandler({ auth }) {
  return async (request) => {
    requireAdmin(request);
    const uid = requireTargetUid(request.data?.uid);
    const enabled = request.data?.enabled;
    if (typeof enabled !== 'boolean') {
      throw new AppError('invalid-argument', 'Indica si el rol debe estar activo.');
    }
    return updateClaim(auth, uid, 'staff', enabled);
  };
}

export function createSetAdminRoleHandler({ auth, bootstrapEmail = '' }) {
  return async (request) => {
    const callerUid = requireUid(request.auth?.uid);
    const uid = requireTargetUid(request.data?.uid);
    const enabled = request.data?.enabled;
    if (typeof enabled !== 'boolean') {
      throw new AppError('invalid-argument', 'Indica si el rol debe estar activo.');
    }

    if (callerUid === uid && !enabled) {
      throw new AppError('failed-precondition', 'Pide a otra persona administradora que retire tu permiso.');
    }

    if (request.auth.token?.admin !== true) {
      const caller = await auth.getUser(callerUid);
      const canBootstrap =
        enabled === true &&
        bootstrapEmail.trim().length > 0 &&
        callerUid === uid &&
        caller.email?.toLowerCase() === bootstrapEmail.trim().toLowerCase() &&
        caller.emailVerified === true;
      if (!canBootstrap) {
        throw new AppError('permission-denied', 'Solo administración puede asignar roles.');
      }
    }

    return updateClaim(auth, uid, 'admin', enabled);
  };
}
