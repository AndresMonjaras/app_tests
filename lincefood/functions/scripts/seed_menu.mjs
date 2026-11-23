import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';

import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { getDatabase } from 'firebase-admin/database';

const [projectId, databaseURL, applyFlag] = process.argv.slice(2);
if (!projectId || !databaseURL || applyFlag !== '--apply') {
  console.error(
    'Uso: node scripts/seed_menu.mjs <projectId> <databaseURL> --apply',
  );
  process.exit(1);
}

const seedPath = new URL('../../firebase/seeds/menu.seed.json', import.meta.url);
const seed = JSON.parse(await readFile(fileURLToPath(seedPath), 'utf8'));
if (!seed.categories || !seed.products) {
  throw new Error('La semilla debe contener categorías y productos.');
}

const app = initializeApp({
  credential: applicationDefault(),
  projectId,
  databaseURL,
});
const database = getDatabase();

async function createIfMissing(path, value) {
  const ref = database.ref(path);
  const result = await ref.transaction((current) =>
    current === null ? value : undefined,
  );
  return result.committed;
}

const addedCategories = [];
const existingCategories = [];
for (const [id, category] of Object.entries(seed.categories)) {
  if (await createIfMissing('categories/' + id, category)) {
    addedCategories.push(id);
  } else {
    existingCategories.push(id);
  }
}

const addedProducts = [];
const existingProducts = [];
for (const [id, product] of Object.entries(seed.products)) {
  if (product.demo !== true || product.imagePath !== 'menu/' + id + '.jpg') {
    throw new Error('La semilla contiene un producto no demostrativo o una ruta inesperada: ' + id);
  }
  if (await createIfMissing('products/' + id, product)) {
    addedProducts.push(id);
  } else {
    existingProducts.push(id);
  }
}

console.log(JSON.stringify({
  projectId,
  addedCategories,
  existingCategories,
  addedProducts,
  existingProducts,
  cafeteriaSettingsChanged: false,
}, null, 2));
await app.delete();
