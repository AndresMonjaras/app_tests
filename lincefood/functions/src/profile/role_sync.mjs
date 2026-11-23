import { getAuth } from 'firebase-admin/auth';
import { onValueWritten } from 'firebase-functions/v2/database';

const region = 'us-central1';

/**
 * El perfil es la fuente administrativa del rol. Se refleja `personal` como
 * claim staff para que Storage y las reglas RTDB puedan autorizar sin permitir
 * que el cliente se otorgue privilegios desde su propio perfil.
 */
export function createProfileRoleSyncHandler({ auth }) {
  return async (event) => {
    const uid = event.params?.uid;
    const role = event.data?.after?.val();
    if (typeof uid !== 'string') return;

    const user = await auth.getUser(uid);
    const claims = { ...(user.customClaims ?? {}) };
    if (role === 'personal') {
      claims.staff = true;
    } else {
      delete claims.staff;
    }
    await auth.setCustomUserClaims(uid, claims);
  };
}

export const synchronizeProfileRole = onValueWritten(
  { ref: '/profiles/{uid}/role', region },
  (event) => createProfileRoleSyncHandler({ auth: getAuth() })(event),
);
