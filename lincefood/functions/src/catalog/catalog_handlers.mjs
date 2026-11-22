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
  return {
    name, categoryId, available, prepMinutes, priceCents, variants, complements,
    description: description.trim(), ingredients: ingredients.map((item) => item.trim()),
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

export function createUpsertProductHandler({ database }) {
  return async (request) => {
    requireAdmin(request);
    const productId = requireProductId(request.data?.productId);
    const product = validateProduct(request.data?.product);
    const ref = database.ref('products/' + productId);
    if (!(await ref.get()).exists()) {
      await ref.update(product);
      return { productId, product };
    }
    const saved = await updateExistingProduct(database, productId, product);
    return { productId, product: saved };
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
    const product = await updateExistingProduct(database, productId, { available });
    return { productId, available: product.available };
  };
}

export function createDeleteProductHandler({ database }) {
  return async (request) => {
    requireAdmin(request);
    const productId = requireProductId(request.data?.productId);
    if (request.data?.confirmed !== true) {
      throw new AppError('failed-precondition', 'Confirma explícitamente el archivado del producto.');
    }
    await updateExistingProduct(database, productId, { archived: true, available: false });
    return { productId, archived: true };
  };
}

async function updateExistingProduct(database, productId, fields) {
  const result = await database.ref('products/' + productId).transaction((current) => {
    // null también puede ser una caché vacía: el servidor debe validar el estado.
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
