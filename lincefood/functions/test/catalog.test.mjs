import test from 'node:test';
import assert from 'node:assert/strict';

import { AppError } from '../src/app_error.mjs';
import {
  createDeleteProductHandler,
  createSetProductAvailabilityHandler,
  createUpdateProductPriceHandler,
  createUpsertProductHandler,
} from '../src/catalog/catalog_handlers.mjs';

function createDatabase({ coldCache = false } = {}) {
  const values = new Map();
  const writes = [];
  return {
    values,
    writes,
    ref(path) {
      return {
        async transaction(update) {
          if (coldCache) {
            // El SDK reintenta con datos del servidor si el hash local no coincide.
            const initial = update(null);
            if (initial === undefined) return { committed: false };
          }
          const value = update(values.get(path) ?? null);
          if (value === undefined) return { committed: false };
          if (value !== null) {
            values.set(path, value);
            writes.push({ path, value });
          }
          return { committed: true, snapshot: { exists: () => value !== null } };
        },
        async set(value) {
          values.set(path, value);
          writes.push({ path, value });
        },
        async remove() {
          values.delete(path);
          writes.push({ path, removed: true });
        },
      };
    },
  };
}

const adminRequest = (data) => ({ auth: { uid: 'admin', token: { admin: true } }, data });

test('todas las operaciones del catálogo rechazan a quien no tiene claim admin', async () => {
  const database = createDatabase();
  const request = { auth: { uid: 'staff', token: { staff: true } }, data: { productId: 'coffee' } };
  for (const makeHandler of [
    createUpsertProductHandler,
    createUpdateProductPriceHandler,
    createSetProductAvailabilityHandler,
    createDeleteProductHandler,
  ]) {
    await assert.rejects(
      makeHandler({ database })(request),
      (error) => error instanceof AppError && error.code === 'permission-denied',
    );
  }
  assert.equal(database.writes.length, 0);
});

test('upsert valida y guarda los precios de producto y variantes como centavos enteros', async () => {
  const database = createDatabase();
  const handler = createUpsertProductHandler({ database });
  const product = {
    name: ' Café ', categoryId: 'bebidas', available: true, priceCents: 2500,
    prepMinutes: 5, variants: [{ label: 'Grande', priceCents: 3000 }],
  };
  await handler(adminRequest({ productId: 'coffee', product }));
  assert.deepEqual(database.values.get('products/coffee'), {
    name: 'Café', categoryId: 'bebidas', available: true, priceCents: 2500,
    prepMinutes: 5, variants: [{ label: 'Grande', priceCents: 3000 }],
  });

  for (const priceCents of [-1, 1.25, Number.MAX_SAFE_INTEGER + 1]) {
    await assert.rejects(
      handler(adminRequest({ productId: 'coffee', product: { ...product, priceCents } })),
      (error) => error instanceof AppError && error.code === 'invalid-argument',
    );
  }
  await assert.rejects(
    handler(adminRequest({ productId: 'coffee', product: {
      ...product, variants: [{ label: 'Chico', priceCents: 1.5 }],
    } })),
    (error) => error instanceof AppError && error.code === 'invalid-argument',
  );
});

test('updateProductPrice rechaza cantidades negativas y decimales', async () => {
  const handler = createUpdateProductPriceHandler({ database: createDatabase() });
  for (const priceCents of [-1, 10.5]) {
    await assert.rejects(
      handler(adminRequest({ productId: 'coffee', priceCents })),
      (error) => error instanceof AppError && error.code === 'invalid-argument',
    );
  }
});

test('disponibilidad requiere booleano y solo cambia ese campo', async () => {
  const database = createDatabase();
  const handler = createSetProductAvailabilityHandler({ database });
  database.values.set('products/coffee', { name: 'Café', priceCents: 1200, available: true });
  await handler(adminRequest({ productId: 'coffee', available: false }));
  assert.deepEqual(database.values.get('products/coffee'), { name: 'Café', priceCents: 1200, available: false });
  await assert.rejects(
    handler(adminRequest({ productId: 'coffee', available: 'false' })),
    (error) => error instanceof AppError && error.code === 'invalid-argument',
  );
});

test('eliminar producto exige confirmación explícita', async () => {
  const database = createDatabase();
  database.values.set('products/coffee', { name: 'Café' });
  const handler = createDeleteProductHandler({ database });
  await assert.rejects(
    handler(adminRequest({ productId: 'coffee' })),
    (error) => error instanceof AppError && error.code === 'failed-precondition',
  );
  assert.equal(database.values.has('products/coffee'), true);

  await handler(adminRequest({ productId: 'coffee', confirmed: true }));
  assert.equal(database.values.has('products/coffee'), false);
});

test('precio y disponibilidad no recrean productos inexistentes', async () => {
  for (const [makeHandler, data] of [
    [createUpdateProductPriceHandler, { priceCents: 100 }],
    [createSetProductAvailabilityHandler, { available: true }],
  ]) {
    const database = createDatabase();
    await assert.rejects(makeHandler({ database })(adminRequest({ productId: 'missing', ...data })),
      (error) => error.code === 'not-found');
    assert.equal(database.writes.length, 0);
  }
});

test('cambiar precio conserva variantes y demás campos', async () => {
  const database = createDatabase();
  const product = { name: 'Café', available: true, priceCents: 100, variants: [{ label: 'Grande', priceCents: 200 }] };
  database.values.set('products/coffee', product);
  await createUpdateProductPriceHandler({ database })(adminRequest({ productId: 'coffee', priceCents: 150 }));
  assert.deepEqual(database.values.get('products/coffee'), { ...product, priceCents: 150 });
});

test('precio actualiza un producto existente aunque la caché inicial esté vacía', async () => {
  const database = createDatabase({ coldCache: true });
  database.values.set('products/coffee', { name: 'Café', available: true, priceCents: 100 });
  await createUpdateProductPriceHandler({ database })(adminRequest({ productId: 'coffee', priceCents: 200 }));
  assert.deepEqual(database.values.get('products/coffee'), { name: 'Café', available: true, priceCents: 200 });
});
