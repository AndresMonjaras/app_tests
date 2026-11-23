import { randomUUID } from 'node:crypto';
import { readdir, stat } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';

import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { getDatabase } from 'firebase-admin/database';
import { getStorage } from 'firebase-admin/storage';

const [projectId, databaseURL, storageBucket] = process.argv.slice(2);
if (!projectId || !databaseURL || !storageBucket) {
  console.error('Uso: node scripts/upload_menu_images.mjs <projectId> <databaseURL> <storageBucket>');
  process.exit(1);
}

const app = initializeApp({ credential: applicationDefault(), projectId, databaseURL, storageBucket });
const database = getDatabase();
const bucket = getStorage().bucket();
const folder = new URL('../../app/assets/images/menu/', import.meta.url);
const entries = await readdir(folder, { withFileTypes: true });

for (const entry of entries) {
  if (!entry.isFile() || !/^[A-Za-z0-9_-]{1,128}\.jpg$/.test(entry.name)) continue;
  const productId = entry.name.slice(0, -4);
  const product = database.ref('products/' + productId);
  if (!(await product.get()).exists()) {
    console.warn('Producto sin registrar:', productId);
    continue;
  }

  const file = fileURLToPath(new URL(entry.name, folder));
  if ((await stat(file)).size > 150_000) {
    throw new Error('La imagen supera 150 KB: ' + entry.name);
  }

  const imagePath = 'menu/' + entry.name;
  await bucket.upload(file, {
    destination: imagePath,
    metadata: {
      contentType: 'image/jpeg',
      metadata: { firebaseStorageDownloadTokens: randomUUID() },
    },
  });
  const result = await product.transaction((current) => {
    if (current === null) return null;
    return { ...current, imagePath };
  });
  if (!result.committed || !result.snapshot.exists()) {
    throw new Error('El producto dejó de existir: ' + productId);
  }
  console.log('Imagen registrada:', productId);
}

await app.delete();
