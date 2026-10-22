/**
 * Build assets/www for the offline Quest APK:
 * - copy public/ with root-relative base
 * - rewrite manifest to ./
 * - vendor three.js + required WebXR controller profiles (no CDN)
 * - point XRControllerModelFactory.setPath at local profiles
 * - scrub github.io / CDN hosts from the package
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { execSync } from 'child_process';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(__dirname, '../..');
const OFFLINE_ROOT = path.join(__dirname, '..');
const WWW_DIR = path.join(OFFLINE_ROOT, 'android/app/src/main/assets/www');
const PUBLIC_DIR = path.join(ROOT, 'public');

const REQUIRED_PROFILES = [
  'meta-quest-touch-plus',
  'meta-quest-touch-plus-v2',
  'meta-quest-touch-pro',
  'oculus-touch',
  'oculus-touch-v2',
  'oculus-touch-v3',
  'generic-trigger',
  'generic-trigger-squeeze-thumbstick'
];

function copyRecursiveSync(src, dest) {
  if (!fs.existsSync(src)) return;
  const stats = fs.statSync(src);
  if (stats.isDirectory()) {
    fs.mkdirSync(dest, { recursive: true });
    for (const name of fs.readdirSync(src)) {
      copyRecursiveSync(path.join(src, name), path.join(dest, name));
    }
  } else {
    fs.mkdirSync(path.dirname(dest), { recursive: true });
    fs.copyFileSync(src, dest);
  }
}

console.log('1. Installing offline dependencies…');
execSync('npm install', { cwd: OFFLINE_ROOT, stdio: 'inherit' });

console.log('2. Creating clean www directory…');
if (fs.existsSync(WWW_DIR)) fs.rmSync(WWW_DIR, { recursive: true, force: true });
fs.mkdirSync(WWW_DIR, { recursive: true });

console.log('3. Copying public/ → assets/www…');
copyRecursiveSync(PUBLIC_DIR, WWW_DIR);

console.log('4. Vendoring three.js…');
const VENDOR_THREE = path.join(WWW_DIR, 'vendor/three');
copyRecursiveSync(
  path.join(OFFLINE_ROOT, 'node_modules/three/build'),
  path.join(VENDOR_THREE, 'build')
);
copyRecursiveSync(
  path.join(OFFLINE_ROOT, 'node_modules/three/examples/jsm'),
  path.join(VENDOR_THREE, 'examples/jsm')
);

console.log('5. Vendoring WebXR controller profiles…');
const profilesSrc = path.join(
  OFFLINE_ROOT,
  'node_modules/@webxr-input-profiles/assets/dist/profiles'
);
const profilesDest = path.join(WWW_DIR, 'vendor/webxr-profiles');
fs.mkdirSync(profilesDest, { recursive: true });
fs.copyFileSync(
  path.join(profilesSrc, 'profilesList.json'),
  path.join(profilesDest, 'profilesList.json')
);
for (const name of REQUIRED_PROFILES) {
  const src = path.join(profilesSrc, name);
  if (!fs.existsSync(src)) {
    console.warn(`  WARN: missing profile ${name}`);
    continue;
  }
  copyRecursiveSync(src, path.join(profilesDest, name));
}

console.log('6. Rewriting index.html importmap (local three)…');
const indexPath = path.join(WWW_DIR, 'index.html');
let indexHtml = fs.readFileSync(indexPath, 'utf-8');
indexHtml = indexHtml.replace(
  /"three":\s*"https:\/\/cdn\.jsdelivr\.net\/npm\/three@[^"]+"/g,
  '"three": "./vendor/three/build/three.module.js"'
);
indexHtml = indexHtml.replace(
  /"three\/addons\/":\s*"https:\/\/cdn\.jsdelivr\.net\/npm\/three@[^"]+\/"/g,
  '"three/addons/": "./vendor/three/examples/jsm/"'
);
fs.writeFileSync(indexPath, indexHtml);

console.log('7. Rewriting web manifest start_url/scope/id to ./ …');
const manifestPath = path.join(WWW_DIR, 'manifest.webmanifest');
if (fs.existsSync(manifestPath)) {
  const m = JSON.parse(fs.readFileSync(manifestPath, 'utf-8'));
  m.id = './';
  m.start_url = './';
  m.scope = './';
  if (Array.isArray(m.icons)) {
    m.icons = m.icons.map((icon) => ({
      ...icon,
      src: String(icon.src || '')
        .replace(/^https?:\/\/[^/]+/i, '')
        .replace(/^\/defuse-protocol\//, './')
        .replace(/^\//, './')
    }));
  }
  fs.writeFileSync(manifestPath, JSON.stringify(m, null, 2));
}

console.log('8. Pointing XRControllerModelFactory.setPath at local profiles…');
const xrPath = path.join(WWW_DIR, 'js/three/xr.js');
if (fs.existsSync(xrPath)) {
  let xr = fs.readFileSync(xrPath, 'utf-8');
  if (!xr.includes('setPath(')) {
    xr = xr.replace(
      /const modelFactory = new XRControllerModelFactory\(\);/,
      "const modelFactory = new XRControllerModelFactory();\n" +
        "  modelFactory.setPath('./vendor/webxr-profiles/');"
    );
  }
  fs.writeFileSync(xrPath, xr);
}

console.log('9. Scrubbing external hosts from text assets…');
const HOST_RE = /sosgit-app\.github\.io|cdn\.jsdelivr\.net|unpkg\.com/gi;
function scrubFile(file) {
  const ext = path.extname(file).toLowerCase();
  if (!['.js', '.mjs', '.html', '.css', '.json', '.webmanifest', '.txt'].includes(ext)) return;
  let text = fs.readFileSync(file, 'utf-8');
  if (!HOST_RE.test(text)) return;
  text = text
    .replace(/https:\/\/sosgit-app\.github\.io\/defuse-protocol\//gi, './')
    .replace(/https:\/\/cdn\.jsdelivr\.net\/npm\/three@[^"'`\s]+/gi, './vendor/three/build/three.module.js')
    .replace(/https:\/\/cdn\.jsdelivr\.net\/[^"'`\s]+/gi, '')
    .replace(/https:\/\/unpkg\.com\/[^"'`\s]+/gi, '');
  fs.writeFileSync(file, text);
}
function walk(dir) {
  for (const name of fs.readdirSync(dir)) {
    const p = path.join(dir, name);
    if (fs.statSync(p).isDirectory()) walk(p);
    else scrubFile(p);
  }
}
walk(WWW_DIR);

console.log('Sync complete →', WWW_DIR);
