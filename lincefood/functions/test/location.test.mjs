import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  createSetCafeteriaLocationHandler,
  createValidateDeliveryLocationHandler,
  haversineMeters,
} from '../src/location/location_handlers.mjs';

const location = {
  lat: 20.54146,
  lng: -100.81192,
  label: 'Cafetería · Campus II',
  address: 'TecNM Celaya Campus II',
  hours: 'Lunes a viernes, 7:30–19:00',
  approximate: true,
};
const coverage = {
  centerLat: location.lat,
  centerLng: location.lng,
  radiusMeters: 350,
  approximate: true,
  note: 'Radio provisional',
};
const admin = { uid: 'admin', token: { admin: true } };
const student = { uid: 'student', token: {} };

test('haversine devuelve metros para puntos dentro y fuera del radio', () => {
  assert.equal(haversineMeters(location.lat, location.lng, location.lat, location.lng), 0);
  const near = haversineMeters(location.lat + 0.002, location.lng, location.lat, location.lng);
  const far = haversineMeters(location.lat, location.lng + 0.005, location.lat, location.lng);
  assert.ok(near > 222 && near < 223);
  assert.ok(far > 520 && far < 522);
});

test('la callable valida contra la cobertura vigente en la base', async () => {
  let currentCoverage = coverage;
  const handler = createValidateDeliveryLocationHandler({
    database: {
      ref(path) {
        assert.equal(path, 'deliveryCoverage');
        return { get: async () => ({ val: () => currentCoverage }) };
      },
    },
  });
  const validate = (lat) => handler({
    auth: student,
    data: { lat, lng: location.lng, radiusMeters: 100_000 },
  });
  assert.equal((await validate(location.lat + 0.002)).withinCoverage, true);
  assert.equal((await validate(location.lat + 0.005)).withinCoverage, false);
  await assert.rejects(validate('20'), { code: 'invalid-argument' });
  await assert.rejects(validate(91), { code: 'invalid-argument' });
  await assert.rejects(handler({ data: location }), { code: 'unauthenticated' });
  currentCoverage = null;
  await assert.rejects(validate(location.lat), { code: 'failed-precondition' });
});

test('solo un admin guarda y las dos configuraciones se escriben juntas', async () => {
  const writes = [];
  const handler = createSetCafeteriaLocationHandler({
    database: { ref: () => ({ update: async (value) => writes.push(value) }) },
  });
  const data = { location, deliveryCoverage: coverage };
  await assert.rejects(handler({ data }), { code: 'unauthenticated' });
  await assert.rejects(handler({ auth: student, data }), { code: 'permission-denied' });
  await assert.rejects(
    handler({ auth: { uid: 'staff', token: { staff: true, admin: 'true' } }, data }),
    { code: 'permission-denied' },
  );
  await assert.rejects(
    handler({ auth: admin, data: { ...data, deliveryCoverage: { ...coverage, radiusMeters: -1 } } }),
    { code: 'invalid-argument' },
  );
  assert.equal(writes.length, 0);
  assert.deepEqual(await handler({ auth: admin, data }), { success: true });
  assert.deepEqual(writes, [{
    'cafeteria/location': location,
    'cafeteria/locationConfigured': true,
    deliveryCoverage: coverage,
  }]);
  await handler({ auth: admin, data: { deliveryCoverage: coverage } });
  assert.deepEqual(writes[1], { deliveryCoverage: coverage });
});
