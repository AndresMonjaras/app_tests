import { AppError } from '../app_error.mjs';
import { roleClaims } from '../roles/role_handlers.mjs';
import {
  auditAuthChange,
  createAudit,
  findTargetUser,
  requireAdmin,
  requireAnotherAdmin,
  withAdminWrite,
} from './admin_access.mjs';

export function createListUsersHandler(deps) {
  const { auth } = deps;
  return async (request) => {
    const actorUid = await requireAdmin(auth, request);
    const { search = '', pageSize = 30, pageToken, role, disabled } = request.data ?? {};
    if (typeof search !== 'string' || search.length > 254 ||
        !Number.isSafeInteger(pageSize) || pageSize < 1 || pageSize > 100 ||
        (pageToken !== undefined && (typeof pageToken !== 'string' || !pageToken || pageToken.length > 8192)) ||
        (role !== undefined && !roleClaims.has(role)) ||
        (disabled !== undefined && typeof disabled !== 'boolean')) {
      throw new AppError('invalid-argument', 'Los filtros o la página no son válidos.');
    }

    const query = search.trim().toLowerCase();
    let nextPageToken = pageToken;
    let users = [];
    // Firebase Auth solo admite paginación. El cursor avanza también en páginas sin coincidencias.
    for (let scanned = 0; scanned < 5; scanned++) {
      const page = await auth.listUsers(pageSize, nextPageToken);
      users = page.users
        .filter((user) => disabled === undefined || user.disabled === disabled)
        .filter((user) => role === undefined || user.customClaims?.[roleClaims.get(role)] === true)
        .filter((user) => !query || [user.email, user.displayName]
          .some((value) => value?.toLowerCase().includes(query)))
        .map((user) => ({
          uid: user.uid,
          email: user.email ?? null,
          displayName: user.displayName ?? null,
          disabled: user.disabled,
          roles: [...roleClaims].filter(([, claim]) => user.customClaims?.[claim] === true)
            .map(([name]) => name),
        }));
      nextPageToken = page.pageToken;
      if (users.length > 0 || !nextPageToken) break;
    }

    const { ref, record } = createAudit(deps, actorUid, 'listUsers', 'users',
      { paginated: pageToken !== undefined }, { returnedCount: users.length });
    await ref.set(record);
    return { users, nextPageToken: nextPageToken ?? null };
  };
}

export function createSetUserDisabledHandler(deps) {
  const { auth, database } = deps;
  return async (request) => {
    const actorUid = await requireAdmin(auth, request);
    const data = request.data ?? {};
    if (typeof data.disabled !== 'boolean') {
      throw new AppError('invalid-argument', 'Indica el estado de la cuenta.');
    }

    return withAdminWrite(database, async () => {
      const target = await findTargetUser(auth, data);
      await requireAdmin(auth, request);
      const { uid, disabled } = target;
      if (uid === actorUid) {
        throw new AppError('failed-precondition', 'Otra persona administradora debe cambiar el estado de tu cuenta.');
      }
      if (data.disabled && target.customClaims?.admin === true) {
        await requireAnotherAdmin(auth, uid);
      }

      await auditAuthChange(deps, actorUid, 'setUserDisabled', uid,
        { disabled }, { disabled: data.disabled },
        () => auth.updateUser(uid, { disabled: data.disabled }));
      return { uid, disabled: data.disabled };
    });
  };
}
