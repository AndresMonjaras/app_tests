import { AppError } from '../app_error.mjs';

function requireSession(request) {
  if (!request.auth?.uid) {
    throw new AppError('unauthenticated', 'Inicia sesión para continuar.');
  }
}

function isCoordinate(value, limit) {
  return Number.isFinite(value) && Math.abs(value) <= limit;
}

function isText(value, maxLength) {
  return typeof value === 'string' && value.trim().length > 0 && value.length <= maxLength;
}

function parseLocation(value) {
  if (!isCoordinate(value?.lat, 90) || !isCoordinate(value?.lng, 180) ||
      !isText(value.label, 100) || !isText(value.address, 300) ||
      !isText(value.hours, 160) || typeof value.approximate !== 'boolean') {
    throw new AppError('invalid-argument', 'La ubicación de la cafetería no es válida.');
  }
  const { lat, lng, label, address, hours, approximate } = value;
  return { lat, lng, label: label.trim(), address: address.trim(), hours: hours.trim(), approximate };
}

function isCoverage(value) {
  return isCoordinate(value?.centerLat, 90) && isCoordinate(value?.centerLng, 180) &&
    Number.isFinite(value.radiusMeters) && value.radiusMeters > 0 &&
    typeof value.approximate === 'boolean' && isText(value.note, 300);
}

export function haversineMeters(lat, lng, centerLat, centerLng) {
  const radians = (degrees) => degrees * Math.PI / 180;
  const halfLat = radians(centerLat - lat) / 2;
  const halfLng = radians(centerLng - lng) / 2;
  const a = Math.sin(halfLat) ** 2 +
    Math.cos(radians(lat)) * Math.cos(radians(centerLat)) * Math.sin(halfLng) ** 2;
  return 2 * 6371000 * Math.asin(Math.sqrt(Math.min(1, a)));
}

export function createSetCafeteriaLocationHandler({ database }) {
  return async (request) => {
    requireSession(request);
    if (request.auth.token?.admin !== true) {
      throw new AppError('permission-denied', 'Solo administración puede cambiar la ubicación.');
    }

    const { location, deliveryCoverage } = request.data ?? {};
    const updates = {};
    if (location !== undefined) {
      updates['cafeteria/location'] = parseLocation(location);
      updates['cafeteria/locationConfigured'] = true;
    }
    if (deliveryCoverage !== undefined) {
      if (!isCoverage(deliveryCoverage)) {
        throw new AppError('invalid-argument', 'La cobertura de entrega no es válida.');
      }
      const { centerLat, centerLng, radiusMeters, approximate, note } = deliveryCoverage;
      updates.deliveryCoverage = { centerLat, centerLng, radiusMeters, approximate, note: note.trim() };
    }
    if (Object.keys(updates).length === 0) {
      throw new AppError('invalid-argument', 'Indica la ubicación o la cobertura de entrega.');
    }
    await database.ref().update(updates);
    return { success: true };
  };
}

export function createValidateDeliveryLocationHandler({ database }) {
  return async (request) => {
    requireSession(request);
    const { lat, lng } = request.data ?? {};
    if (!isCoordinate(lat, 90) || !isCoordinate(lng, 180)) {
      throw new AppError('invalid-argument', 'Las coordenadas de entrega no son válidas.');
    }

    const coverage = (await database.ref('deliveryCoverage').get()).val();
    if (!isCoverage(coverage)) {
      throw new AppError('failed-precondition', 'La cobertura de entrega no está configurada.');
    }
    const distanceMeters = haversineMeters(lat, lng, coverage.centerLat, coverage.centerLng);
    return { withinCoverage: distanceMeters <= coverage.radiusMeters, distanceMeters };
  };
}
