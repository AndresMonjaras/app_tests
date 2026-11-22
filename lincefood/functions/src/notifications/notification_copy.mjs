import { readFile } from 'node:fs/promises';

const deployedSeedUrl = new URL('./notificaciones.seed.json', import.meta.url);

export async function loadNotificationCopies() {
  return JSON.parse(await readFile(deployedSeedUrl, 'utf8'));
}
