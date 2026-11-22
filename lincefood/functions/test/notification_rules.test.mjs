import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';

const rulesUrl = new URL('../../firebase/database.rules.json', import.meta.url);

test('las reglas de tokens limitan lectura y escritura al propietario', async () => {
  const { rules } = JSON.parse(await readFile(rulesUrl, 'utf8'));
  const tokens = rules.notificationTokens;

  assert.equal(tokens.$uid['.read'], false);
  assert.equal(tokens.$uid.$tokenHash['.write'], 'auth != null && auth.uid === $uid');
  assert.match(tokens.$uid.$tokenHash['.validate'], /hasChildren/);
  assert.equal(tokens.$uid.$tokenHash.$other['.validate'], false);
});

test('el inbox solo se puede leer por usuario y solo permite cambiar su lectura', async () => {
  const { rules } = JSON.parse(await readFile(rulesUrl, 'utf8'));
  const inbox = rules.notificationInbox.$uid;

  assert.equal(inbox['.read'], 'auth != null && auth.uid === $uid');
  assert.equal(inbox.$notificationId['.write'], undefined);
  assert.equal(
    inbox.$notificationId.isRead['.write'],
    'auth != null && auth.uid === $uid',
  );
  assert.equal(inbox.$notificationId.$other['.validate'], false);
});
