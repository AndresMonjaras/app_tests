import { AppError } from './app_error.mjs';

function asVariants(product) {
  const variants = product?.variants;
  if (Array.isArray(variants)) return variants;
  if (variants && typeof variants === 'object') return Object.values(variants);
  return [];
}

function getPrice(product, variantLabel, lineNumber) {
  const variants = asVariants(product);

  if (variants.length > 0) {
    if (typeof variantLabel !== 'string' || variantLabel.length === 0) {
      throw new AppError(
        'invalid-argument',
        'Selecciona una variante para cada producto que la tenga.',
      );
    }

    const variant = variants.find(
      (item) => item && item.label === variantLabel,
    );
    if (!variant) {
      throw new AppError(
        'invalid-argument',
        'La variante de la línea ' + lineNumber + ' no existe.',
      );
    }
    if (variant.available === false) {
      throw new AppError(
        'failed-precondition',
        'La variante seleccionada en la línea ' + lineNumber + ' está agotada.',
      );
    }
    return { priceCents: variant.priceCents, variantLabel: variant.label };
  }

  if (variantLabel !== undefined && variantLabel !== null) {
    throw new AppError(
      'invalid-argument',
      'El producto de la línea ' + lineNumber + ' no tiene variantes.',
    );
  }
  return { priceCents: product.priceCents, variantLabel: null };
}

export function validateAndPriceOrderLines(rawLines, products) {
  if (!Array.isArray(rawLines) || rawLines.length === 0) {
    throw new AppError('invalid-argument', 'El carrito está vacío.');
  }
  if (!products || typeof products !== 'object') {
    throw new AppError(
      'failed-precondition',
      'El catálogo no está disponible.',
    );
  }

  const lines = rawLines.map((rawLine, index) => {
    const lineNumber = index + 1;
    if (!rawLine || typeof rawLine !== 'object' || Array.isArray(rawLine)) {
      throw new AppError(
        'invalid-argument',
        'La línea ' + lineNumber + ' no es válida.',
      );
    }

    const { productId, quantity, variantLabel } = rawLine;
    if (typeof productId !== 'string' || productId.trim().length === 0) {
      throw new AppError(
        'invalid-argument',
        'Cada línea debe incluir un producto.',
      );
    }
    if (!Number.isInteger(quantity) || quantity < 1 || quantity > 20) {
      throw new AppError(
        'invalid-argument',
        'La cantidad de cada producto debe estar entre 1 y 20.',
      );
    }

    const product = products[productId];
    if (!product || product.archived === true || product.available !== true) {
      throw new AppError(
        'failed-precondition',
        'El producto de la línea ' + lineNumber + ' no está disponible.',
      );
    }

    const selected = getPrice(product, variantLabel, lineNumber);
    if (!Number.isSafeInteger(selected.priceCents) || selected.priceCents < 0) {
      throw new AppError(
        'failed-precondition',
        'El precio del producto de la línea ' + lineNumber + ' no es válido.',
      );
    }

    const totalCents = selected.priceCents * quantity;
    if (!Number.isSafeInteger(totalCents)) {
      throw new AppError('invalid-argument', 'El total excede el límite válido.');
    }

    return {
      productId,
      productName: String(product.name || productId),
      variantLabel: selected.variantLabel,
      quantity,
      unitPriceCents: selected.priceCents,
      totalCents,
    };
  });

  const totalCents = lines.reduce((sum, line) => sum + line.totalCents, 0);
  if (!Number.isSafeInteger(totalCents)) {
    throw new AppError('invalid-argument', 'El total excede el límite válido.');
  }

  return { lines, totalCents };
}
