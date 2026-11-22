import { readFile } from 'node:fs/promises';
import { after, before, beforeEach, describe, it } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { getBytes, ref, uploadBytes } from 'firebase/storage';

const projectId = 'lincefood-app';
const bucketUrl = `gs://${projectId}.firebasestorage.app`;
const validJpeg = Uint8Array.from([0xff, 0xd8, 0xff, 0xd9]);
const tooLargeImage = new Uint8Array(2 * 1024 * 1024 + 1);

let testEnvironment;

before(async () => {
  const rules = await readFile(
    new URL('../firebase/storage.rules', import.meta.url),
    'utf8',
  );

  testEnvironment = await initializeTestEnvironment({
    projectId,
    storage: {
      rules,
      host: '127.0.0.1',
      port: 9199,
    },
  });
});

beforeEach(async () => {
  await testEnvironment.clearStorage();
});

after(async () => {
  await testEnvironment?.cleanup();
});

describe('reglas de Firebase Storage', () => {
  it('bloquea la lectura y escritura anónima de avatares', async () => {
    const ownerStorage = testEnvironment
      .authenticatedContext('owner', {
        email_verified: true,
        firebase: { sign_in_provider: 'password' },
      })
      .storage(bucketUrl);
    const avatarPath = 'profiles/owner/avatar/avatar';
    await assertSucceeds(
      uploadBytes(ref(ownerStorage, avatarPath), validJpeg, {
        contentType: 'image/jpeg',
      }),
    );

    const anonymousStorage = testEnvironment
      .unauthenticatedContext()
      .storage(bucketUrl);
    await assertFails(getBytes(ref(anonymousStorage, avatarPath)));
    await assertFails(
      uploadBytes(ref(anonymousStorage, avatarPath), validJpeg, {
        contentType: 'image/jpeg',
      }),
    );
  });

  it('solo permite escribir imágenes de menú a usuarios con claim admin', async () => {
    const path = 'menu/product-1/image.jpg';
    const userStorage = testEnvironment
      .authenticatedContext('user')
      .storage(bucketUrl);
    const anonymousStorage = testEnvironment
      .unauthenticatedContext()
      .storage(bucketUrl);

    await assertFails(
      uploadBytes(ref(userStorage, path), validJpeg, {
        contentType: 'image/jpeg',
      }),
    );
    await assertFails(
      uploadBytes(ref(anonymousStorage, path), validJpeg, {
        contentType: 'image/jpeg',
      }),
    );
  });

  it('permite al administrador subir JPEG y deja leerlo públicamente', async () => {
    const adminStorage = testEnvironment
      .authenticatedContext('admin', { admin: true })
      .storage(bucketUrl);
    const path = 'menu/product-1/image.jpg';

    await assertSucceeds(
      uploadBytes(ref(adminStorage, path), validJpeg, {
        contentType: 'image/jpeg',
      }),
    );

    const anonymousStorage = testEnvironment
      .unauthenticatedContext()
      .storage(bucketUrl);
    await assertSucceeds(getBytes(ref(anonymousStorage, path)));
  });

  it('permite una imagen de menú de exactamente 2 MiB', async () => {
    const adminStorage = testEnvironment
      .authenticatedContext('admin', { admin: true })
      .storage(bucketUrl);

    await assertSucceeds(
      uploadBytes(
        ref(adminStorage, 'menu/product-1/exact-limit.jpg'),
        new Uint8Array(2 * 1024 * 1024),
        { contentType: 'image/jpeg' },
      ),
    );
  });

  it('no permite lectura pública de un objeto que no sea imagen', async () => {
    const path = 'menu/product-1/document.pdf';

    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      await uploadBytes(ref(context.storage(bucketUrl), path), validJpeg, {
        contentType: 'application/pdf',
      });
    });

    const anonymousStorage = testEnvironment
      .unauthenticatedContext()
      .storage(bucketUrl);
    await assertFails(getBytes(ref(anonymousStorage, path)));
  });

  it('rechaza SVG en el menú', async () => {
    const adminStorage = testEnvironment
      .authenticatedContext('admin', { admin: true })
      .storage(bucketUrl);

    await assertFails(
      uploadBytes(ref(adminStorage, 'menu/product-1/image.svg'), validJpeg, {
        contentType: 'image/svg+xml',
      }),
    );
  });

  it('rechaza imágenes de menú mayores a 2 MiB', async () => {
    const adminStorage = testEnvironment
      .authenticatedContext('admin', { admin: true })
      .storage(bucketUrl);

    await assertFails(
      uploadBytes(ref(adminStorage, 'menu/product-1/large.jpg'), tooLargeImage, {
        contentType: 'image/jpeg',
      }),
    );
  });

  it('rechaza tipos de archivo que no sean imágenes permitidas', async () => {
    const adminStorage = testEnvironment
      .authenticatedContext('admin', { admin: true })
      .storage(bucketUrl);

    await assertFails(
      uploadBytes(ref(adminStorage, 'menu/product-1/document.pdf'), validJpeg, {
        contentType: 'application/pdf',
      }),
    );
  });

  it('permite al dueño leer y actualizar su avatar con claims válidos', async () => {
    const ownerStorage = testEnvironment
      .authenticatedContext('owner', {
        email_verified: true,
        firebase: { sign_in_provider: 'password' },
      })
      .storage(bucketUrl);
    const avatarPath = 'profiles/owner/avatar/avatar';

    await assertSucceeds(
      uploadBytes(ref(ownerStorage, avatarPath), validJpeg, {
        contentType: 'image/jpeg',
      }),
    );
    await assertSucceeds(getBytes(ref(ownerStorage, avatarPath)));
  });

  it('requiere correo verificado y acceso con correo para escribir el avatar', async () => {
    const unverifiedStorage = testEnvironment
      .authenticatedContext('owner', {
        email_verified: false,
        firebase: { sign_in_provider: 'password' },
      })
      .storage(bucketUrl);
    const providerStorage = testEnvironment
      .authenticatedContext('owner', {
        email_verified: true,
        firebase: { sign_in_provider: 'google.com' },
      })
      .storage(bucketUrl);
    const avatarPath = 'profiles/owner/avatar/avatar';

    await assertFails(
      uploadBytes(ref(unverifiedStorage, avatarPath), validJpeg, {
        contentType: 'image/jpeg',
      }),
    );
    await assertFails(
      uploadBytes(ref(providerStorage, avatarPath), validJpeg, {
        contentType: 'image/jpeg',
      }),
    );
  });

  it('bloquea al usuario que intenta leer un avatar ajeno', async () => {
    const ownerStorage = testEnvironment
      .authenticatedContext('owner', {
        email_verified: true,
        firebase: { sign_in_provider: 'password' },
      })
      .storage(bucketUrl);
    const avatarPath = 'profiles/owner/avatar/avatar';
    await assertSucceeds(
      uploadBytes(ref(ownerStorage, avatarPath), validJpeg, {
        contentType: 'image/jpeg',
      }),
    );

    const otherUserStorage = testEnvironment
      .authenticatedContext('other-user')
      .storage(bucketUrl);
    await assertFails(getBytes(ref(otherUserStorage, avatarPath)));
  });
});
