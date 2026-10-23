import { cp, mkdir, writeFile, symlink, lstat, access } from 'node:fs/promises';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { tmpdir } from 'node:os';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const destination = resolve(tmpdir(), 'twildiary-ios-reference-b43454e');
// A fresh, named reference workspace. Never copy an existing database, credential or browser profile.
await mkdir(destination, { recursive: true });
for (const name of ['src', 'static', 'tooling', 'drizzle', 'package.json', 'package-lock.json', 'tsconfig.json', 'vite.config.ts', 'wrangler.jsonc']) {
  await cp(resolve(root, name), resolve(destination, name), { recursive: true });
}
try { await lstat(resolve(destination, 'node_modules')); }
catch { await symlink(resolve(root, 'node_modules'), resolve(destination, 'node_modules'), process.platform === 'win32' ? 'junction' : 'dir'); }
// This token is deliberately fictional: browser fixture routes intercept all provider traffic.
// It only enables connected-layout rendering in the isolated reference copy, and is never copied from .dev.vars.
await writeFile(resolve(destination, '.dev.vars'), 'LOCAL_DIARY=1\nTMDB_ACCESS_TOKEN=ios-reference-fixture-not-a-credential\n', {mode: 0o600});
await writeFile(resolve(root, '.local/ios-reference-workspace.json'), JSON.stringify({path: destination, port: 5193}) + '\n');
console.log(destination);
