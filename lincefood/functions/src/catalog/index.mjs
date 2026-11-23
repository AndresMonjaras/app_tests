import { getDatabase } from 'firebase-admin/database';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { AppError } from '../app_error.mjs';
import {
  createDeleteProductHandler,
  createSetProductAvailabilityHandler,
  createRestoreProductHandler,
  createUpdateProductPriceHandler,
  createUpsertProductHandler,
} from './catalog_handlers.mjs';

import {
  createUpsertCategoryHandler,
  createDeleteCategoryHandler,
  createUpsertUnitHandler,
  createDeleteUnitHandler
} from './taxonomy_handlers.mjs';

const region = 'us-central1';

function withCallableErrors(handlerFactory) {
  return async (request) => {
    try {
      return await handlerFactory({ database: getDatabase() })(request);
    } catch (error) {
      if (error instanceof AppError) throw new HttpsError(error.code, error.message);
      throw new HttpsError('internal', 'No se pudo completar la operación.');
    }
  };
}

export const upsertProduct = onCall(
  { region },
  withCallableErrors(createUpsertProductHandler),
);
export const updateProductPrice = onCall(
  { region },
  withCallableErrors(createUpdateProductPriceHandler),
);
export const setProductAvailability = onCall(
  { region },
  withCallableErrors(createSetProductAvailabilityHandler),
);
export const deleteProduct = onCall(
  { region },
  withCallableErrors(createDeleteProductHandler),
);
export const restoreProduct = onCall(
  { region },
  withCallableErrors(createRestoreProductHandler),
);

export const upsertCategory = onCall({ region }, withCallableErrors(createUpsertCategoryHandler));
export const deleteCategory = onCall({ region }, withCallableErrors(createDeleteCategoryHandler));
export const upsertUnit = onCall({ region }, withCallableErrors(createUpsertUnitHandler));
export const deleteUnit = onCall({ region }, withCallableErrors(createDeleteUnitHandler));
