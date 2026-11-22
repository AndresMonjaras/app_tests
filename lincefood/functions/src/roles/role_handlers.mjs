import { AppError } from '../app_error.mjs';
import {
  auditAuthChange,
  callerUid,
  findTargetUser,
  requireAdmin,
  requireAnotherAdmin,
  withAdminWrite,
} from '../admin/admin_access.mjs';

export const roleClaims = new Map([
  ['superadmin', 'admin'],
  ['cafeteria_staff', 'staff'],
  ['delivery_staff', 'delivery'],
]);

export function createSetUserRoleHandler(deps, legacyRole) {
  const { auth, database, bootstrapEmail = '' } = deps;
  return async (request) => {
    const actorUid = callerUid(request);
    const data = request.data ?? {};
    const role = legacyRole ?? data.role;
    const claim = roleClaims.get(role);
    if (!claim || typeof data.enabled !== 'boolean') {
      throw new AppError('invalid-argument', 'Indica un rol válido y si debe estar activo.');
    }

    const bootstrap = legacyRole === 'superadmin' &&
      request.auth.token?.admin !== true && data.enabled && data.uid === actorUid;

    if (bootstrap) {
      requireBootstrapAccount(await findTargetUser(auth, data), bootstrapEmail);
    } else {
      await requireAdmin(auth, request);
    }

    return withAdminWrite(database, async () => {
      const target = await findTargetUser(auth, data);
      const uid = target.uid;
      const claims = { ...target.customClaims };
      if (bootstrap) {
        requireBootstrapAccount(target, bootstrapEmail);
        await requireNoOtherAdmin(auth, uid);
      } else {
        await requireAdmin(auth, request);
      }
      if (claim === 'admin' && !data.enabled) {
        if (actorUid === uid) {
          throw new AppError('failed-precondition', 'Pide a otra persona administradora que retire tu permiso.');
        }
        if (claims.admin === true) await requireAnotherAdmin(auth, uid);
      }

      const previous = claims[claim] === true;
      if (data.enabled) {
        claims[claim] = true;
      } else {
        delete claims[claim];
      }
      await auditAuthChange(deps, actorUid, 'setUserRole', uid,
        { role, enabled: previous }, { role, enabled: data.enabled },
        () => auth.setCustomUserClaims(uid, claims));
      return { uid, [claim]: data.enabled };
    });
  };
}

function requireBootstrapAccount(target, bootstrapEmail) {
  const email = bootstrapEmail.trim().toLowerCase();
  const allowed = email && target.email?.toLowerCase() === email &&
    !target.disabled && target.emailVerified === true &&
    target.customClaims?.staff !== true && target.customClaims?.delivery !== true;
  if (!allowed) {
    throw new AppError('permission-denied', 'Solo administración puede asignar roles.');
  }
}

async function requireNoOtherAdmin(auth, uid) {
  try {
    await requireAnotherAdmin(auth, uid);
  } catch (error) {
    if (error instanceof AppError && error.code === 'failed-precondition') return;
    throw error;
  }
  throw new AppError('permission-denied', 'Solo administración puede asignar roles.');
}

export function createSetStaffRoleHandler(deps) {
  return createSetUserRoleHandler(deps, 'cafeteria_staff');
}

export function createSetAdminRoleHandler(deps) {
  return createSetUserRoleHandler(deps, 'superadmin');
}
