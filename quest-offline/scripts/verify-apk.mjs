/**
 * Pre-upload checks required by the working offline Quest recipe.
 */
import { spawnSync } from 'child_process';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { execSync } from 'child_process';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(__dirname, '..');
const APK =
  process.argv[2] ||
  path.join(ROOT, 'android/app/build/outputs/apk/release/app-release-unsigned.apk');
const ANDROID_HOME =
  process.env.ANDROID_HOME || path.join(process.env.LOCALAPPDATA || '', 'Android', 'Sdk');

function findAapt() {
  const bt = path.join(ANDROID_HOME, 'build-tools');
  if (!fs.existsSync(bt)) return null;
  for (const v of fs.readdirSync(bt).sort().reverse()) {
    for (const name of ['aapt.exe', 'aapt2.exe', 'aapt', 'aapt2']) {
      const p = path.join(bt, v, name);
      if (fs.existsSync(p)) return p;
    }
  }
  return null;
}

function listZip(apkPath) {
  // jar tf works on APKs
  try {
    const out = execSync(`jar tf "${apkPath}"`, { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
    return out.split(/\r?\n/).filter(Boolean);
  } catch {
    const ps = `
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::OpenRead('${apkPath.replace(/'/g, "''")}').Entries | ForEach-Object { $_.FullName }
`;
    const out = execSync(`powershell -NoProfile -Command "${ps.replace(/\n/g, '; ')}"`, {
      encoding: 'utf8',
      maxBuffer: 64 * 1024 * 1024
    });
    return out.split(/\r?\n/).filter(Boolean);
  }
}

if (!fs.existsSync(APK)) {
  console.error('APK not found:', APK);
  process.exit(1);
}

const names = listZip(APK);
let failed = false;

function check(label, ok) {
  console.log(ok ? `OK  ${label}` : `FAIL ${label}`);
  if (!ok) failed = true;
}

check('assets/www/index.html', names.includes('assets/www/index.html'));
check(
  'lib/arm64-v8a/libopenxr_loader.so',
  names.includes('lib/arm64-v8a/libopenxr_loader.so')
);
check(
  'webxr profilesList.json',
  names.includes('assets/www/vendor/webxr-profiles/profilesList.json')
);
check(
  'meta-quest-touch-plus profile',
  names.some((n) => n.includes('webxr-profiles/meta-quest-touch-plus/'))
);

// Grep packaged JS/HTML for live site host via temporary extract of index + main
const tmp = path.join(ROOT, '.verify-tmp');
fs.rmSync(tmp, { recursive: true, force: true });
fs.mkdirSync(tmp, { recursive: true });
try {
  execSync(`jar xf "${APK}" assets/www/index.html assets/www/js/main.js assets/www/manifest.webmanifest`, {
    cwd: tmp,
    stdio: 'ignore'
  });
} catch {
  /* jar xf may fail if paths missing — already checked index */
}
const hostHits = [];
function scan(rel) {
  const p = path.join(tmp, rel);
  if (!fs.existsSync(p)) return;
  const text = fs.readFileSync(p, 'utf-8');
  if (/sosgit-app\.github\.io/i.test(text)) hostHits.push(rel);
}
scan('assets/www/index.html');
scan('assets/www/js/main.js');
scan('assets/www/manifest.webmanifest');
check('no sosgit-app.github.io in index/main/manifest', hostHits.length === 0);
if (hostHits.length) hostHits.forEach((h) => console.log('   still in', h));
fs.rmSync(tmp, { recursive: true, force: true });

const aapt = findAapt();
if (aapt && path.basename(aapt).startsWith('aapt') && !path.basename(aapt).includes('2')) {
  const r = spawnSync(aapt, ['dump', 'badging', APK], { encoding: 'utf8' });
  const out = (r.stdout || '') + (r.stderr || '');
  console.log('\n--- aapt badging (excerpt) ---');
  for (const line of out.split(/\r?\n/)) {
    if (/package:|sdkVersion|targetSdkVersion|native-code|application-label/.test(line)) {
      console.log(line);
    }
  }
  check("package com.smallerbytes.defuseprotocol", /name='com\.smallerbytes\.defuseprotocol'/.test(out));
  check('targetSdkVersion 34', /targetSdkVersion:'?34'?/.test(out));
  const nativeLine = /native-code:.*arm64-v8a/.test(out);
  const nativeInZip = names.includes('lib/arm64-v8a/libopenxr_loader.so');
  check('native-code arm64-v8a (badging or zip)', nativeLine || nativeInZip);
} else {
  const btDir = aapt ? path.dirname(aapt) : null;
  const classic = btDir && fs.existsSync(path.join(btDir, 'aapt.exe'))
    ? path.join(btDir, 'aapt.exe')
    : btDir && fs.existsSync(path.join(btDir, 'aapt'))
      ? path.join(btDir, 'aapt')
      : null;
  if (classic) {
    const r = spawnSync(classic, ['dump', 'badging', APK], { encoding: 'utf8' });
    const out = (r.stdout || '') + (r.stderr || '');
    console.log('\n--- aapt badging (excerpt) ---');
    for (const line of out.split(/\r?\n/)) {
      if (/^package:|^sdkVersion:|^targetSdkVersion:|^native-code:|^application-label:/.test(line)) {
        console.log(line);
      }
    }
    check("package com.smallerbytes.defuseprotocol", /name='com\.smallerbytes\.defuseprotocol'/.test(out));
    check('targetSdkVersion 34', /targetSdkVersion:'?34'?/.test(out));
    check(
      'native-code arm64-v8a (badging or zip)',
      /native-code:.*arm64-v8a/.test(out) || names.includes('lib/arm64-v8a/libopenxr_loader.so')
    );
  } else {
    console.log('WARN aapt not found — skipped badging checks');
  }
}

if (failed) {
  console.error('\nVerification FAILED');
  process.exit(1);
}
console.log('\nVerification PASSED — ready to sign and upload');
