/**
 * Sign the already-built unsigned APK (no Gradle rebuild).
 */
import { spawnSync } from 'child_process';
import fs from 'fs';
import path from 'path';
import readline from 'readline';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(__dirname, '..');
const KEYSTORE = path.join(ROOT, 'android.keystore');
const ANDROID_HOME = process.env.ANDROID_HOME || path.join(process.env.LOCALAPPDATA || '', 'Android', 'Sdk');

const candidates = [
  path.join(ROOT, 'app', 'build', 'outputs', 'apk', 'release', 'app-release-unsigned.apk'),
  path.join(ROOT, 'app-release-unsigned-aligned.apk')
];
const inputApk = candidates.find((p) => fs.existsSync(p));
const signed = path.join(ROOT, 'app-release-signed.apk');
const aligned = path.join(ROOT, 'app-release-to-sign.apk');

function ask(prompt) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  return new Promise((resolve) => rl.question(prompt, (a) => { rl.close(); resolve(a); }));
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
  const r = spawnSync(cmd, args, {
    cwd: ROOT,
    stdio: 'inherit',
    shell: true
  });
  if (r.error) {
    console.error(r.error);
    process.exit(1);
  }
  if (r.status !== 0) {
    console.error(`Command failed with exit code ${r.status}`);
    process.exit(r.status || 1);
  }
}

if (!inputApk) {
  console.error('No unsigned APK found. Run: npm run build:windows');
  process.exit(1);
}
if (!fs.existsSync(KEYSTORE)) {
  console.error('Missing android.keystore');
  process.exit(1);
}

const zipalign = findTool('zipalign.exe');
const apksigner = findTool('apksigner.bat');
if (!apksigner) {
  console.error('apksigner.bat not found under Android SDK build-tools');
  process.exit(1);
}

console.log(`Signing:\n  ${inputApk}\n`);
const storePass = await ask('Keystore password: ');
if (!storePass) process.exit(1);
const keyPass = (await ask('Key password (Enter = same): ')) || storePass;

// Always write to a different path than the input (zipalign forbids same file).
if (zipalign) {
  run(zipalign, ['-f', '-p', '4', inputApk, aligned]);
} else {
  fs.copyFileSync(inputApk, aligned);
}

run(apksigner, [
  'sign',
  '--ks', KEYSTORE,
  '--ks-key-alias', 'android',
  '--ks-pass', `pass:${storePass}`,
  '--key-pass', `pass:${keyPass}`,
  '--out', signed,
  aligned
]);

run(apksigner, ['verify', '--verbose', signed]);

console.log(`\nSUCCESS — upload THIS file to Alpha:\n\n  ${signed}\n`);
console.log('Do NOT upload unsigned / aligned files.');
