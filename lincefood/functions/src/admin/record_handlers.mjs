import { AppError } from '../app_error.mjs';
import {
  createAudit,
  findTargetUser,
  requireAdmin,
  requireKey,
  withAdminWrite,
} from './admin_access.mjs';

function validDate(value) {
  return Number.isSafeInteger(value) && value >= 0 && value <= 8_640_000_000_000_000;
}

function validatePromotion(data) {
  const { discountPercent, discountCents, active, startsAt, endsAt } = data;
  const title = typeof data.title === 'string' ? data.title.trim() : '';
  const description = typeof data.description === 'string' ? data.description.trim() : null;
  if (!title || title.length > 120 || description === null || description.length > 1000 ||
      typeof active !== 'boolean' || !validDate(startsAt) || !validDate(endsAt) || endsAt <= startsAt) {
    throw new AppError('invalid-argument', 'Revisa el título, la descripción y las fechas de la promoción.');
  }

  const percent = Number.isInteger(discountPercent) && discountPercent >= 1 && discountPercent <= 90;
  const cents = Number.isSafeInteger(discountCents) && discountCents > 0;
  if (percent && discountCents === undefined) {
    return { title, description, discountPercent, active, startsAt, endsAt };
  }
  if (cents && discountPercent === undefined) {
    return { title, description, discountCents, active, startsAt, endsAt };
  }
  throw new AppError('invalid-argument', 'Indica un porcentaje entero de 1 a 90 o un importe positivo en centavos.');
}

function createRecordHandler(deps, action, prepare) {
  const { auth, database } = deps;
  return async (request) => {
    const actorUid = await requireAdmin(auth, request);
    return withAdminWrite(database, async () => {
      await requireAdmin(auth, request);
      const { path, target, before, after } = await prepare(request.data ?? {}, actorUid);
      const { ref, record } = createAudit(deps, actorUid, action, target, before, after);
      await database.ref().update({
        [path]: after,
        [`adminAudit/${ref.key}`]: record,
      });
      return { id: target };
    });
  };
}

async function readRecord(database, path, required = true) {
  const value = (await database.ref(path).get()).val();
  if (required && value === null) throw new AppError('not-found', 'No se encontró el registro.');
  return value;
}

export function createUpsertPromotionHandler(deps) {
  const { database } = deps;
  return createRecordHandler(deps, 'upsertPromotion', async (data) => {
    const after = validatePromotion(data);
    const editing = data.id !== undefined;
    const target = editing ? requireKey(data.id) : database.ref('promotions').push().key;
    const path = `promotions/${target}`;
    const before = editing ? await readRecord(database, path) : null;
    return { path, target, before, after };
  });
}

export function createDeactivatePromotionHandler(deps) {
  const { database } = deps;
  return createRecordHandler(deps, 'deactivatePromotion', async (data) => {
    const target = requireKey(data.id);
    const path = `promotions/${target}`;
    const before = await readRecord(database, path);
    return { path, target, before, after: { ...before, active: false } };
  });
}

export function createUpsertScholarshipHandler(deps) {
  const { auth, database, serverTimestamp } = deps;
  return createRecordHandler(deps, 'upsertScholarship', async (data, actorUid) => {
    const { type, remainingUses } = data;
    if (type !== 'meal' || !Number.isSafeInteger(remainingUses) || remainingUses < 0) {
      throw new AppError('invalid-argument', 'Indica una beca de comida con un número entero de usos desde cero.');
    }
    const user = await findTargetUser(auth, data);
    const target = requireKey(user.uid);
    const path = `scholarships/${target}`;
    const before = await readRecord(database, path, false);
    const after = {
      type,
      remainingUses,
      assignedBy: before?.assignedBy ?? actorUid,
      updatedAt: serverTimestamp(),
    };
    return { path, target, before, after };
  });
}

export function createRevokeScholarshipHandler(deps) {
  const { database } = deps;
  return createRecordHandler(deps, 'revokeScholarship', async (data) => {
    const target = requireKey(data.uid);
    const path = `scholarships/${target}`;
    const before = await readRecord(database, path);
    return { path, target, before, after: null };
  });
}
