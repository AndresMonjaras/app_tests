import test from 'node:test';
import assert from 'node:assert/strict';

import { AppError } from '../src/app_error.mjs';
import {
  createDeleteProductHandler,
  createRestoreProductHandler,
  createSetProductAvailabilityHandler,
  createUpdateProductPriceHandler,
  createUpsertProductHandler,
} from '../src/catalog/catalog_handlers.mjs';

function createDatabase({ coldCache = false } = {}) {
  const values = new Map();
  const writes = [];
  let auditCount = 0;
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
          if (path === '/') {
            const root = {};
            for (const [entry, value] of values) {
              const [collection, key] = entry.split('/');
              if (key) (root[collection] ??= {})[key] = value;
              else root[collection] = value;
            }
            const next = update(root);
            for (const [key, value] of Object.entries(next.products ?? {})) {
              values.set('products/' + key, value);
            }
            return { committed: true, snapshot: { exists: () => true, val: () => next } };
          }
          const value = update(values.get(path) ?? null);
          if (value === undefined) return { committed: false };
          if (value !== null) {
            values.set(path, value);
            writes.push({ path, value });
          }
          return { committed: true, snapshot: { exists: () => value !== null, val: () => value } };
        },
        async get() {
          return {
            exists: () => values.has(path),
            val: () => values.get(path) ?? null,
            child: (key) => ({ exists: () => values.has(path + '/' + key) }),
          };
        },
        async update(fields) {
          const value = { ...values.get(path), ...fields };
          values.set(path, value);
          writes.push({ path, value });
        },
        push() {
          auditCount += 1;
          const auditPath = path + '/audit-' + auditCount;
          return {
            async set(value) {
              values.set(auditPath, value);
              writes.push({ path: auditPath, value });
            },
          };
        },
      };
    },
  };
}

const adminRequest = (data) => ({ auth: { uid: 'admin', token: { admin: true } }, data });

test('las operaciones del catálogo permiten staff y rechazan usuarios sin rol', async () => {
  const database = createDatabase();
  const request = { auth: { uid: 'user', token: {} }, data: { productId: 'coffee' } };
  for (const makeHandler of [
    createUpsertProductHandler,
    createUpdateProductPriceHandler,
    createSetProductAvailabilityHandler,
    createDeleteProductHandler,
    createRestoreProductHandler,
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
    prepMinutes: 5, variants: [{ label: 'Grande', priceCents: 3000, available: true }],
    description: '', ingredients: [], complements: [],
  });

  for (const priceCents of [0, -1, 1.25, Number.MAX_SAFE_INTEGER + 1]) {
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
  for (const priceCents of [0, -1, 10.5]) {
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

test('archivar exige confirmación y conserva producto y pedidos', async () => {
  const database = createDatabase({ coldCache: true });
  const product = { name: 'Café', priceCents: 100, available: true };
  const order = { lines: [{ productId: 'coffee', unitPriceCents: 200 }] };
  database.values.set('products/coffee', product);
  database.values.set('orders/order1', order);
  const handler = createDeleteProductHandler({ database });
  await assert.rejects(
    handler(adminRequest({ productId: 'coffee' })),
    (error) => error instanceof AppError && error.code === 'failed-precondition',
  );
  assert.deepEqual(database.values.get('products/coffee'), product);

  assert.deepEqual(await handler(adminRequest({ productId: 'coffee', confirmed: true })),
    { productId: 'coffee', archived: true });
  assert.deepEqual(database.values.get('products/coffee'),
    { ...product, archived: true, available: false });
  await createSetProductAvailabilityHandler({ database })(adminRequest({
    productId: 'coffee', available: true,
  }));
  assert.equal(database.values.get('products/coffee').available, false);
  assert.deepEqual(database.values.get('orders/order1'), order);
});

test('guardar en caché fría conserva la foto, la marca demo y el archivado', async () => {
  const database = createDatabase({ coldCache: true });
  const handler = createUpsertProductHandler({ database });
  database.values.set('products/coffee', {
    archived: true, demo: true, imagePath: 'menu/coffee.jpg', available: false,
  });
  const product = {
    name: 'Café', categoryId: 'drinks', priceCents: 100, available: true,
    description: ' Café americano ', ingredients: [' Café '],
    variants: [{ label: 'Grande', priceCents: 200, available: false }],
    complements: [{ label: 'Leche', priceCents: 50, available: true }],
  };
  const result = await handler(adminRequest({ productId: 'coffee', product }));
  assert.deepEqual(result.product, {
    ...product, description: 'Café americano', ingredients: ['Café'],
    archived: true, demo: true, imagePath: 'menu/coffee.jpg', available: false,
    prepMinutes: 0,
  });

  for (const field of ['variants', 'complements']) {
    for (const options of [
      Array.from({ length: 7 }, (_, i) => ({ label: 'Opción ' + i, priceCents: 50 })),
      [{ label: 'a'.repeat(41), priceCents: 50 }],
      [{ label: 'Opción', priceCents: 0 }],
      [{ label: 'Opción', priceCents: 1.2 }],
      [{ label: 'Opción', priceCents: 50, available: null }],
      [{ label: 'Opción', priceCents: 50 }, { label: ' opción ', priceCents: 50 }],
    ]) {
      await assert.rejects(handler(adminRequest({
        productId: 'coffee', product: { ...product, [field]: options },
      })), { code: 'invalid-argument' });
    }
  }
});

test('precio y disponibilidad no recrean productos inexistentes', async () => {
  for (const [makeHandler, data] of [
    [createUpdateProductPriceHandler, { priceCents: 100 }],
    [createSetProductAvailabilityHandler, { available: true }],
    [createDeleteProductHandler, { confirmed: true }],
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

test('las unidades del catálogo sustituyen las semillas cuando existe units', async () => {
  const database = createDatabase({ coldCache: true });
  const save = createUpsertProductHandler({ database });
  const product = { name: 'Pan', categoryId: 'pan', available: true, priceCents: 10, portionAmount: 1 };
  const request = (portionUnit) => adminRequest({ productId: 'pan', product: { ...product, portionUnit } });
  for (const code of ['g', 'ml', 'pz']) await save(request(code));
  await assert.rejects(save(request('kg')), { code: 'invalid-argument' });
  database.values.set('units', { kg: { label: 'Kilogramos', symbol: 'kg' } });
  await save(request('kg'));
  await assert.rejects(save(request('g')), { code: 'invalid-argument' });
});
