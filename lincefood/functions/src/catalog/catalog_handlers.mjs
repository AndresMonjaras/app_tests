import { AppError } from '../app_error.mjs';

function requireAdmin(request) {
  if (typeof request.auth?.uid !== 'string' || request.auth.uid.length === 0) {
    throw new AppError('unauthenticated', 'Inicia sesión para continuar.');
  }
  if (request.auth.token?.admin !== true) {
    throw new AppError('permission-denied', 'Solo administración puede editar el catálogo.');
  }
}

function requireProductId(value) {
  if (typeof value !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(value)) {
    throw new AppError('invalid-argument', 'El producto no es válido.');
  }
  return value;
}

function requirePrice(value) {
  if (!Number.isSafeInteger(value) || value < 0) {
    throw new AppError('invalid-argument', 'El precio debe ser un entero en centavos mayor o igual a cero.');
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
  if (name.length < 1 || name.length > 100 || categoryId.length > 100) {
    throw new AppError('invalid-argument', 'Revisa el nombre y la categoría del producto.');
  }
  if (typeof available !== 'boolean') {
    throw new AppError('invalid-argument', 'La disponibilidad no es válida.');
  }
  if (!Number.isInteger(prepMinutes) || prepMinutes < 0 || prepMinutes > 240) {
    throw new AppError('invalid-argument', 'El tiempo de preparación no es válido.');
  }
  const priceCents = requirePrice(value.priceCents);
  const variants = value.variants ?? [];
  if (!Array.isArray(variants) || variants.length > 6) {
    throw new AppError('invalid-argument', 'El producto puede tener hasta 6 variantes.');
  }
  const cleanVariants = variants.map((variant) => {
    const label = typeof variant?.label === 'string' ? variant.label.trim() : '';
    if (label.length < 1 || label.length > 40) {
      throw new AppError('invalid-argument', 'Cada variante necesita un nombre de hasta 40 caracteres.');
    }
    return { label, priceCents: requirePrice(variant.priceCents) };
  });
  return { name, categoryId, available, prepMinutes, priceCents, variants: cleanVariants };
}

export function createUpsertProductHandler({ database }) {
  return async (request) => {
    requireAdmin(request);
    const productId = requireProductId(request.data?.productId);
    const product = validateProduct(request.data?.product);
    await database.ref('products/' + productId).set(product);
    return { productId, product };
  };
}

export function createUpdateProductPriceHandler({ database }) {
  return async (request) => {
    requireAdmin(request);
    const productId = requireProductId(request.data?.productId);
    const priceCents = requirePrice(request.data?.priceCents);
    await updateExistingProduct(database, productId, { priceCents });
    return { productId, priceCents };
  };
}

export function createSetProductAvailabilityHandler({ database }) {
  return async (request) => {
    requireAdmin(request);
    const productId = requireProductId(request.data?.productId);
    const available = request.data?.available;
    if (typeof available !== 'boolean') {
      throw new AppError('invalid-argument', 'La disponibilidad no es válida.');
    }
    await updateExistingProduct(database, productId, { available });
    return { productId, available };
  };
}

export function createDeleteProductHandler({ database }) {
  return async (request) => {
    requireAdmin(request);
    const productId = requireProductId(request.data?.productId);
    if (request.data?.confirmed !== true) {
      throw new AppError('failed-precondition', 'Confirma explícitamente la eliminación del producto.');
    }
    await database.ref('products/' + productId).remove();
    return { productId, deleted: true };
  };
}

async function updateExistingProduct(database, productId, fields) {
  const result = await database.ref('products/' + productId).transaction((current) => {
    // null también puede ser una caché vacía: el servidor debe validar el estado.
    if (current === null) return null;
    return { ...current, ...fields };
  });
  if (!result.committed || !result.snapshot.exists()) {
    throw new AppError('not-found', 'El producto ya no existe. Actualiza el catálogo.');
  }
}
