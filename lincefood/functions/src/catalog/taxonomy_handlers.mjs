import { AppError } from '../app_error.mjs';
import { requireCatalogEditor, recordCatalogAudit } from './catalog_handlers.mjs';
import { defaultUnits, unitCodePattern } from './units.mjs';

function validKey(value, pattern) {
  if (typeof value !== 'string' || !pattern.test(value)) {
    throw new AppError('invalid-argument', 'El identificador no es válido.');
  }
  return value;
}

function validText(value, max) {
  const text = typeof value === 'string' ? value.trim() : '';
  if (!text || text.length > max) {
    throw new AppError('invalid-argument', 'Revisa el texto y su longitud.');
  }
  return text;
}

const categoryKey = /^[A-Za-z0-9_-]{1,100}$/;

function taxonomyHandler(action, collection, deleting) {
  return ({ database, serverTimestamp = () => Date.now() }) => async (request) => {
    const actor = requireCatalogEditor(request);
    const data = request.data ?? {};
    const unit = collection === 'units';
    const key = unit ? validKey(data.code, unitCodePattern)
      : validKey(!deleting && data.id === undefined ? database.ref(collection).push().key : data.id, categoryKey);
    let after = null;
    if (!deleting) {
      after = unit ? { label: validText(data.label, 100), symbol: validText(data.symbol, 10) }
        : validText(data.name, 100);
    }
    // La transacción reintenta si un producto empieza a usar la clave durante el borrado.
    const ref = database.ref(deleting ? '/' : collection);
    let before;
    await ref.transaction((current) => {
      if (deleting && current === null && !unit) return null;
      const root = deleting ? (current ?? {}) : null;
      if (deleting && Object.values(root.products ?? {}).some(
        (product) => product?.[unit ? 'portionUnit' : 'categoryId'] === key,
      )) {
        throw new AppError('failed-precondition', unit
          ? 'Un producto usa esta unidad.' : 'Un producto usa esta categoría.');
      }
      const entries = { ...((deleting ? root[collection] : current) ?? (unit ? defaultUnits : {})) };
      before = Object.hasOwn(entries, key) ? entries[key] : null;
      if (deleting) delete entries[key];
      else Object.defineProperty(entries, key, { value: after, enumerable: true, configurable: true });
      return deleting ? { ...root, [collection]: entries } : entries;
    });
    await recordCatalogAudit(database, serverTimestamp, actor, action, key, before, after);
    return unit ? { code: key } : { id: key };
  };
}

export const createUpsertCategoryHandler = taxonomyHandler('upsertCategory', 'categories', false);
export const createDeleteCategoryHandler = taxonomyHandler('deleteCategory', 'categories', true);
export const createUpsertUnitHandler = taxonomyHandler('upsertUnit', 'units', false);
export const createDeleteUnitHandler = taxonomyHandler('deleteUnit', 'units', true);
