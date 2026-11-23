import { AppError } from './app_error.mjs';

function asVariants(product) {
  const variants = product?.variants;
  if (Array.isArray(variants)) return variants;
  if (variants && typeof variants === 'object') return Object.values(variants);
  return [];
}

function asComplements(product) {
  const complements = product?.complements;
  if (Array.isArray(complements)) return complements;
  if (complements && typeof complements === 'object') {
    return Object.values(complements);
  }
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
    const complementLabels = rawLine.complementLabels ?? [];
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

    if (
      !Array.isArray(complementLabels) ||
      complementLabels.length > 6 ||
      complementLabels.some(
        (label) =>
          typeof label !== 'string' || label.length === 0 || label.length > 40,
      ) ||
      new Set(complementLabels).size !== complementLabels.length
    ) {
      throw new AppError(
        'invalid-argument',
        'Los complementos de la línea ' + lineNumber + ' no son válidos.',
      );
    }
    const productComplements = asComplements(product);
    const complements = complementLabels.map((label) => {
      const complement = productComplements.find(
        (item) => item && item.label === label,
      );
      if (!complement) {
        throw new AppError(
          'invalid-argument',
          'Un complemento de la línea ' + lineNumber + ' no existe.',
        );
      }
      if (complement.available === false) {
        throw new AppError(
          'failed-precondition',
          'Un complemento de la línea ' + lineNumber + ' está agotado.',
        );
      }
      if (!Number.isSafeInteger(complement.priceCents) || complement.priceCents < 0) {
        throw new AppError(
          'failed-precondition',
          'El precio de un complemento de la línea ' + lineNumber + ' no es válido.',
        );
      }
      return { label: complement.label, priceCents: complement.priceCents };
    });
    const unitPriceCents = selected.priceCents +
      complements.reduce((sum, item) => sum + item.priceCents, 0);
    if (!Number.isSafeInteger(unitPriceCents)) {
      throw new AppError('invalid-argument', 'El total excede el límite válido.');
    }
    const totalCents = unitPriceCents * quantity;
    if (!Number.isSafeInteger(totalCents)) {
      throw new AppError('invalid-argument', 'El total excede el límite válido.');
    }

    return {
      productId,
      productName: String(product.name || productId),
      variantLabel: selected.variantLabel,
      complements,
      quantity,
      unitPriceCents,
      totalCents,
    };
  });

  const totalCents = lines.reduce((sum, line) => sum + line.totalCents, 0);
  if (!Number.isSafeInteger(totalCents)) {
    throw new AppError('invalid-argument', 'El total excede el límite válido.');
  }

  return { lines, totalCents };
}
