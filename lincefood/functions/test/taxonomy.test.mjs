import test from 'node:test';
import assert from 'node:assert/strict';
import {
  createUpsertCategoryHandler, createDeleteCategoryHandler,
  createUpsertUnitHandler, createDeleteUnitHandler,
} from '../src/catalog/taxonomy_handlers.mjs';

function fixture() {
  let root = {};
  const audit = [];
  const database = {
    ref(path) {
      return {
        push: () => ({ key: 'nuevo', set: async (value) => audit.push(value) }),
        async transaction(update) {
          if (path === '/') root = update(root);
          else root[path] = update(root[path] ?? null);
          return { committed: true };
        },
      };
    },
  };
  return { database, audit, read: () => root };
}

for (const [kind, collection, field, saveFactory, deleteFactory, initial, edit, invalid] of [
  ['categoría', 'categories', 'categoryId', createUpsertCategoryHandler, createDeleteCategoryHandler,
    { name: 'Sopa' }, { id: 'nuevo', name: 'Sopas' }, { id: 'a/b' }],
  ['unidad', 'units', 'portionUnit', createUpsertUnitHandler, createDeleteUnitHandler,
    { code: 'kg', label: 'Kilo', symbol: 'k' }, { code: 'kg', label: 'Kilogramos', symbol: 'kg' }, { code: 'KG' }],
]) {
  test('crear, editar y borrar ' + kind, async () => {
    const { database, audit, read } = fixture();
    const save = saveFactory({ database });
    const remove = deleteFactory({ database });
    const staff = (data) => ({ auth: { uid: 's', token: { staff: true } }, data });
    const key = edit.id ?? edit.code;
    for (const handler of [save, remove]) {
      await assert.rejects(handler({ auth: { uid: 'c', token: {} }, data: edit }), { code: 'permission-denied' });
      await assert.rejects(handler(staff({ ...edit, ...invalid })), { code: 'invalid-argument' });
    }
    assert.deepEqual(await save(staff(initial)), edit.id ? { id: key } : { code: key });
    await save(staff(edit));
    assert.deepEqual(read()[collection][key], edit.name ?? { label: edit.label, symbol: edit.symbol });
    if (collection === 'units') assert.deepEqual(Object.keys(read().units).sort(), ['g', 'kg', 'ml', 'pz']);
    for (const archived of [false, true]) {
      read().products = { pan: { [field]: key, archived } };
      await assert.rejects(remove(staff(edit)), { code: 'failed-precondition' });
    }
    delete read().products;
    await remove(staff(edit));
    assert.equal(Object.hasOwn(read()[collection], key), false);
    assert.equal(audit.length, 3);
    assert.equal(audit[2].actorRole, 'staff');
  });
}
