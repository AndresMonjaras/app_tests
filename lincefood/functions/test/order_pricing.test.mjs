import assert from 'node:assert/strict';
import test from 'node:test';

import { AppError } from '../src/app_error.mjs';
import { validateAndPriceOrderLines } from '../src/order_pricing.mjs';

const products = {
  sandwich: {
    name: 'Sándwich',
    available: true,
    variants: [
      { label: 'Chico', priceCents: 3000 },
      { label: 'Grande', priceCents: 4000 },
    ],
  },
  water: { name: 'Agua fresca', available: true, priceCents: 2000 },
  soldOut: { name: 'Agotado', available: false, priceCents: 1000 },
};

test('calcula precios de catálogo y total en centavos', () => {
  const result = validateAndPriceOrderLines(
    [
      { productId: 'sandwich', variantLabel: 'Grande', quantity: 2 },
      { productId: 'water', quantity: 1 },
    ],
    products,
  );

  assert.equal(result.totalCents, 10000);
  assert.deepEqual(result.lines[0], {
    productId: 'sandwich',
    productName: 'Sándwich',
    variantLabel: 'Grande',
    quantity: 2,
    unitPriceCents: 4000,
    totalCents: 8000,
  });
});

test('rechaza cantidades fuera del rango permitido', () => {
  for (const quantity of [0, 21, 1.5]) {
    assert.throws(
      () =>
        validateAndPriceOrderLines(
          [{ productId: 'water', quantity }],
          products,
        ),
      (error) => error instanceof AppError && error.code === 'invalid-argument',
    );
  }
});

test('rechaza productos inexistentes y no disponibles', () => {
  for (const productId of ['missing', 'soldOut']) {
    assert.throws(
      () =>
        validateAndPriceOrderLines(
          [{ productId, quantity: 1 }],
          products,
        ),
      (error) =>
        error instanceof AppError && error.code === 'failed-precondition',
    );
  }
});

test('rechaza variantes ausentes o inexistentes', () => {
  assert.throws(
    () =>
      validateAndPriceOrderLines(
        [{ productId: 'sandwich', quantity: 1 }],
        products,
      ),
    AppError,
  );
  assert.throws(
    () =>
      validateAndPriceOrderLines(
        [{ productId: 'sandwich', variantLabel: 'Familiar', quantity: 1 }],
        products,
      ),
    AppError,
  );
});

test('rechaza carritos vacíos', () => {
  assert.throws(
    () => validateAndPriceOrderLines([], products),
    (error) => error instanceof AppError && error.code === 'invalid-argument',
  );
});
