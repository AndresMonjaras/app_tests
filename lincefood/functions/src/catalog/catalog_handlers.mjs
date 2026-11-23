import { defaultUnits, unitCodePattern } from './units.mjs';
import { AppError } from '../app_error.mjs';

export function requireCatalogEditor(request) {
  if (typeof request.auth?.uid !== 'string' || request.auth.uid.length === 0) {
    throw new AppError('unauthenticated', 'Inicia sesión para continuar.');
  }
  if (request.auth.token?.admin !== true && request.auth.token?.staff !== true) {
    throw new AppError('permission-denied', 'Solo el personal de cafetería puede editar el catálogo.');
  }
  return { uid: request.auth.uid, role: request.auth.token?.admin === true ? 'admin' : 'staff' };
}

function requireProductId(value) {
  if (typeof value !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(value)) {
    throw new AppError('invalid-argument', 'El producto no es válido.');
  }
  return value;
}

function requirePrice(value) {
  if (!Number.isSafeInteger(value) || value <= 0) {
    throw new AppError('invalid-argument', 'El precio debe ser un entero en centavos mayor a cero.');
  }
  return value;
}

function validateProduct(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new AppError('invalid-argument', 'Los datos del producto no son válidos.');
  }
  const name = typeof value.name === 'string' ? value.name.trim() : '';
  const categoryId = typeof value.categoryId === 'string' ? value.categoryId.trim() : '';
  const available = value.available;
  const prepMinutes = value.prepMinutes ?? 0;
  if (name.length < 1 || name.length > 100 || categoryId.length < 1 || categoryId.length > 100) {
    throw new AppError('invalid-argument', 'Revisa el nombre y la categoría del producto.');
  }
  if (typeof available !== 'boolean') {
    throw new AppError('invalid-argument', 'La disponibilidad no es válida.');
  }
  if (!Number.isInteger(prepMinutes) || prepMinutes < 0 || prepMinutes > 240) {
    throw new AppError('invalid-argument', 'El tiempo de preparación no es válido.');
  }
  const priceCents = requirePrice(value.priceCents);
  const description = (value.description ?? '');
  if (typeof description !== 'string' || description.length > 1000) {
    throw new AppError('invalid-argument', 'La descripción debe tener hasta 1000 caracteres.');
  }
  const ingredients = value.ingredients ?? [];
  if (!Array.isArray(ingredients) || ingredients.length > 30 ||
      ingredients.some((item) => typeof item !== 'string' || !item.trim() || item.trim().length > 80)) {
    throw new AppError('invalid-argument', 'Usa hasta 30 ingredientes de hasta 80 caracteres.');
  }
  const variants = validateOptions(value.variants ?? [], 'variantes');
  const complements = validateOptions(value.complements ?? [], 'complementos');
  const portionAmount = value.portionAmount ?? null;
  const portionUnit = value.portionUnit ?? null;
  if (portionAmount !== null && (!Number.isSafeInteger(portionAmount) || portionAmount <= 0)) {
    throw new AppError('invalid-argument', 'La cantidad de la porción debe ser un entero positivo.');
  }
  if (portionUnit !== null && (typeof portionUnit !== 'string' || !unitCodePattern.test(portionUnit))) {
    throw new AppError('invalid-argument', 'La unidad de porción no es válida.');
  }
  if ((portionAmount === null) !== (portionUnit === null)) {
    throw new AppError('invalid-argument', 'Indica cantidad y unidad de porción.');
  }
  const imagePath = value.imagePath ?? '';
  if (typeof imagePath !== 'string' || (imagePath !== '' &&
      (!imagePath.startsWith('menu/') || imagePath.includes('..') || imagePath.includes('//')))) {
    throw new AppError('invalid-argument', 'La ruta de imagen no es válida.');
  }
  return {
    name, categoryId, available, prepMinutes, priceCents, variants, complements,
    description: description.trim(), ingredients: ingredients.map((item) => item.trim()),
    ...(Object.hasOwn(value, 'portionAmount') ? { portionAmount } : {}),
    ...(Object.hasOwn(value, 'portionUnit') ? { portionUnit } : {}),
    ...(Object.hasOwn(value, 'imagePath') ? { imagePath: imagePath || null } : {}),
  };
}

function validateOptions(options, kind) {
  if (!Array.isArray(options) || options.length > 6) {
    throw new AppError('invalid-argument', 'El producto puede tener hasta 6 ' + kind + '.');
  }
  const labels = new Set();
  return options.map((option) => {
    const label = typeof option?.label === 'string' ? option.label.trim() : '';
    if (!label || label.length > 40 || labels.has(label.toLowerCase())) {
      throw new AppError('invalid-argument', 'Los nombres deben ser únicos y de hasta 40 caracteres.');
    }
    labels.add(label.toLowerCase());
    const available = option.available === undefined ? true : option.available;
    if (typeof available !== 'boolean') {
      throw new AppError('invalid-argument', 'La disponibilidad de la opción no es válida.');
    }
    return { label, priceCents: requirePrice(option.priceCents), available };
  });
}

export function createUpsertProductHandler({ database, serverTimestamp = () => Date.now() }) {
  return async (request) => {
    const actor = requireCatalogEditor(request);
    const productId = requireProductId(request.data?.productId);
    const product = validateProduct(request.data?.product);
    const before = await readProduct(database, productId);
    const isNewProductImage = typeof product.imagePath === 'string' &&
      product.imagePath.startsWith(`menu/${productId}/`);
    const isUnchangedLegacyImage = typeof product.imagePath === 'string' &&
      product.imagePath !== '' &&
      product.imagePath === before?.imagePath &&
      product.imagePath.startsWith('menu/') &&
      !product.imagePath.includes('..') &&
      !product.imagePath.includes('//');
    if (product.imagePath && !isNewProductImage && !isUnchangedLegacyImage) {
      throw new AppError('invalid-argument', 'La imagen debe pertenecer al producto.');
    }
    const saved = await upsertExistingProduct(database, productId, {
      ...product,
    });
    await recordCatalogAudit(database, serverTimestamp, actor, 'upsertProduct', productId, before, saved);
    return { productId, product: saved };
  };
}

export function createUpdateProductPriceHandler({ database, serverTimestamp = () => Date.now() }) {
  return async (request) => {
    const actor = requireCatalogEditor(request);
    const productId = requireProductId(request.data?.productId);
    const priceCents = requirePrice(request.data?.priceCents);
    const before = await readProduct(database, productId);
    const saved = await updateExistingProduct(database, productId, {
      priceCents,
    });
    await recordCatalogAudit(database, serverTimestamp, actor, 'updateProductPrice', productId, before, saved);
    return { productId, priceCents };
  };
}

export function createSetProductAvailabilityHandler({ database, serverTimestamp = () => Date.now() }) {
  return async (request) => {
    const actor = requireCatalogEditor(request);
    const productId = requireProductId(request.data?.productId);
    const available = request.data?.available;
    if (typeof available !== 'boolean') {
      throw new AppError('invalid-argument', 'La disponibilidad no es válida.');
    }
    const before = await readProduct(database, productId);
    const product = await updateExistingProduct(database, productId, {
      available,
    });
    await recordCatalogAudit(database, serverTimestamp, actor, 'setProductAvailability', productId, before, product);
    return { productId, available: product.available };
  };
}

export function createDeleteProductHandler({ database, serverTimestamp = () => Date.now() }) {
  return async (request) => {
    const actor = requireCatalogEditor(request);
    const productId = requireProductId(request.data?.productId);
    if (request.data?.confirmed !== true) {
      throw new AppError('failed-precondition', 'Confirma explícitamente el archivado del producto.');
    }
    const before = await readProduct(database, productId);
    const product = await updateExistingProduct(database, productId, {
      archived: true, available: false,
    });
    await recordCatalogAudit(database, serverTimestamp, actor, 'archiveProduct', productId, before, product);
    return { productId, archived: true };
  };
}

export function createRestoreProductHandler({ database, serverTimestamp = () => Date.now() }) {
  return async (request) => {
    const actor = requireCatalogEditor(request);
    const productId = requireProductId(request.data?.productId);
    const before = await readProduct(database, productId);
    if (!before?.archived) {
      throw new AppError('failed-precondition', 'El producto no está archivado.');
    }
    const product = await updateExistingProduct(database, productId, {
      archived: false, available: true,
    });
    await recordCatalogAudit(database, serverTimestamp, actor, 'restoreProduct', productId, before, product);
    return { productId, archived: false };
  };
}

async function readProduct(database, productId) {
  const snapshot = await database.ref('products/' + productId).get();
  return snapshot.exists() ? snapshot.val() : null;
}

export async function recordCatalogAudit(database, serverTimestamp, actor, action, target, before, after) {
  const ref = database.ref('adminAudit').push();
  const record = {
    actorUid: actor.uid,
    actorRole: actor.role,
    action,
    target,
    before: before ?? { exists: false },
    after: after ?? { exists: false },
    at: serverTimestamp(),
  };
  await ref.set(record);
}

async function upsertExistingProduct(database, productId, fields) {
  // Las referencias y el producto deben corresponder a la misma versión del catálogo.
  let validationError;
  const result = await database.ref('/').transaction((root) => {
    validationError = null;
    if (fields.portionUnit != null && !Object.hasOwn(root?.units ?? defaultUnits, fields.portionUnit)) {
      validationError = new AppError('invalid-argument', 'La unidad de porción no es válida.');
      return root;
    }
    if (root?.categories && !Object.hasOwn(root.categories, fields.categoryId)) {
      validationError = new AppError('failed-precondition', 'Selecciona una categoría existente.');
      return root;
    }
    root ??= {};
    const current = root.products?.[productId];
    const product = { ...current, ...fields };
    for (const [key, value] of Object.entries(fields)) {
      if (value === null) delete product[key];
    }
    if (product.archived === true) product.available = false;
    return { ...root, products: { ...root.products, [productId]: product } };
  });
  if (validationError) throw validationError;
  if (!result.committed || !result.snapshot.exists()) {
    throw new AppError('aborted', 'No se pudo guardar el producto. Inténtalo de nuevo.');
  }
  return result.snapshot.val().products[productId];
}

async function updateExistingProduct(database, productId, fields) {
  const result = await database.ref('products/' + productId).transaction((current) => {
    // El Admin SDK puede iniciar sin caché: null provoca lectura y reintento.
    if (current === null) return null;
    const product = { ...current, ...fields };
    if (product.archived === true) product.available = false;
    return product;
  });
  if (!result.committed || !result.snapshot.exists()) {
    throw new AppError('not-found', 'El producto ya no existe. Actualiza el catálogo.');
  }
  return result.snapshot.val();
}
