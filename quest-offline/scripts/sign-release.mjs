/**
 * Sign quest-offline release APK with the same keystore as Alpha (defusalapplab).
 * Usage: node scripts/sign-release.mjs
 * Env: BUBBLEWRAP_KEYSTORE_PASSWORD (and optional BUBBLEWRAP_KEY_PASSWORD)
 */
import { spawnSync } from 'child_process';
import fs from 'fs';
import path from 'path';
import readline from 'readline';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(__dirname, '..');
const KEYSTORE = path.join(ROOT, '..', 'defusalapplab', 'android.keystore');
const INPUT = path.join(
  ROOT,
  'android',
  'app',
  'build',
  'outputs',
  'apk',
  'release',
  'app-release-unsigned.apk'
);
const ALIGNED = path.join(ROOT, 'app-release-aligned.apk');
const SIGNED = path.join(ROOT, 'app-release-signed.apk');
const ANDROID_HOME =
  process.env.ANDROID_HOME || path.join(process.env.LOCALAPPDATA || '', 'Android', 'Sdk');

function ask(prompt) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  return new Promise((resolve) => {
    rl.question(prompt, (a) => {
      rl.close();
      resolve(a);
    });
  });
}

function findTool(name) {
  const bt = path.join(ANDROID_HOME, 'build-tools');
  const versions = fs.readdirSync(bt).sort().reverse();
  for (const v of versions) {
    const p = path.join(bt, v, name);
    if (fs.existsSync(p)) return p;
  }
  return null;
}

function run(cmd, args) {
  console.log(`\n> ${cmd} ${args.join(' ')}`);
  const r = spawnSync(cmd, args, { stdio: 'inherit', shell: true });
  if (r.status !== 0) process.exit(r.status || 1);
}

if (!fs.existsSync(KEYSTORE)) {
  console.error('Missing defusalapplab/android.keystore');
  process.exit(1);
}
if (!fs.existsSync(INPUT)) {
  console.error('Missing unsigned APK. Build first:\n  cd quest-offline && npm run sync && cd android && gradlew.bat :app:assembleRelease');
  process.exit(1);
}

const zipalign = findTool('zipalign.exe') || findTool('zipalign');
const apksigner = findTool('apksigner.bat') || findTool('apksigner');
if (!zipalign || !apksigner) {
  console.error('zipalign/apksigner not found under ANDROID_HOME:', ANDROID_HOME);
  process.exit(1);
}

let pass = process.env.BUBBLEWRAP_KEYSTORE_PASSWORD || '';
if (!pass) pass = await ask('Keystore password: ');
const keyPass = process.env.BUBBLEWRAP_KEY_PASSWORD || pass;

if (fs.existsSync(ALIGNED)) fs.unlinkSync(ALIGNED);
if (fs.existsSync(SIGNED)) fs.unlinkSync(SIGNED);

run(zipalign, ['-f', '-p', '4', INPUT, ALIGNED]);
run(apksigner, [
  'sign',
  '--ks', KEYSTORE,
  '--ks-key-alias', 'android',
  '--ks-pass', `pass:${pass}`,
  '--key-pass', `pass:${keyPass}`,
  '--out', SIGNED,
  ALIGNED
]);
run(apksigner, ['verify', '--verbose', SIGNED]);

console.log('\nSigned APK ready for Meta Alpha upload:\n ', SIGNED);
