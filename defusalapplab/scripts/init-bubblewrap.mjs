/**
 * Prepare defusalapplab for Meta Bubblewrap packaging.
 * Does not run the interactive wizard — uses twa-manifest.template.json.
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { execSync, spawnSync } from 'child_process';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(__dirname, '..');
const TEMPLATE = path.join(ROOT, 'twa-manifest.template.json');
const MANIFEST = path.join(ROOT, 'twa-manifest.json');
const KEYSTORE = path.join(ROOT, 'android.keystore');

function which(cmd) {
  const r = spawnSync(process.platform === 'win32' ? 'where' : 'which', [cmd], { encoding: 'utf8' });
  return r.status === 0 ? r.stdout.trim().split(/\r?\n/)[0] : null;
}

console.log('Defuse Protocol — App Lab Bubblewrap init\n');

if (!fs.existsSync(TEMPLATE)) {
  console.error('Missing twa-manifest.template.json');
  process.exit(1);
}

if (!fs.existsSync(MANIFEST)) {
  fs.copyFileSync(TEMPLATE, MANIFEST);
  console.log('Created twa-manifest.json from template.');
  console.log('  Edit host / startUrl if you use SmallerBytes Pages instead of sos.');
} else {
  console.log('twa-manifest.json already exists — leaving it alone.');
}

console.log('\nInstalling @meta-quest/bubblewrap-cli (global)…');
try {
  execSync('npm install -g @meta-quest/bubblewrap-cli', { stdio: 'inherit' });
} catch {
  console.warn('Global install failed — try: npm install -g @meta-quest/bubblewrap-cli');
}

if (!fs.existsSync(KEYSTORE)) {
  const keytool =
    which('keytool') ||
    (() => {
      const jdk = process.env.JAVA_HOME && path.join(process.env.JAVA_HOME, 'bin', process.platform === 'win32' ? 'keytool.exe' : 'keytool');
      return jdk && fs.existsSync(jdk) ? jdk : null;
    })();

  // Prefer Temurin 17 if present (same JDK used for quest-offline builds).
  const temurin = 'C:\\Program Files\\Eclipse Adoptium\\jdk-17.0.20.101-hotspot\\bin\\keytool.exe';
  const kt = keytool || (fs.existsSync(temurin) ? temurin : null);

  if (!kt) {
    console.log('\nNo keytool found. Install JDK 17, then create a keystore:');
    console.log('  keytool -genkeypair -v -keystore android.keystore -alias android -keyalg RSA -keysize 2048 -validity 10000');
  } else {
    console.log('\nCreating android.keystore (you will be prompted for passwords + identity)…');
    console.log('Remember these passwords — every App Lab update must use the same key.\n');
    try {
      execSync(
        `"${kt}" -genkeypair -v -keystore "${KEYSTORE}" -alias android -keyalg RSA -keysize 2048 -validity 10000`,
        { stdio: 'inherit', cwd: ROOT, shell: true }
      );
    } catch {
      console.warn('Keystore creation skipped or failed — create android.keystore manually before build.');
    }
  }
} else {
  console.log('\nandroid.keystore already present.');
}

console.log(`
Next steps:
  1. Deploy public/ to GitHub Pages (manifest + icons + .well-known must be live).
  2. npm run fingerprint   → paste SHA-256 into public/.well-known/assetlinks.json
  3. Redeploy Pages so assetlinks.json is public.
  4. npm run update && npm run build
  5. Upload app-release-signed.apk in Meta Developer Dashboard (App Lab).

Docs: https://developers.meta.com/horizon/documentation/web/pwa-packaging/
`);
