/**
 * Thin wrapper so npm scripts can call: bubblewrap <command>
 */
import { spawnSync } from 'child_process';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(__dirname, '..');
const cmd = process.argv[2] || 'build';
const extra = process.argv.slice(3);

if (!fs.existsSync(path.join(ROOT, 'twa-manifest.json'))) {
  console.error('Missing twa-manifest.json — run: npm run init');
  process.exit(1);
}

const r = spawnSync('bubblewrap', [cmd, ...extra], {
  cwd: ROOT,
  stdio: 'inherit',
  shell: true,
  env: process.env
});

process.exit(r.status ?? 1);
