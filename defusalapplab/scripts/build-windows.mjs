/**
 * Windows build that bypasses Bubblewrap's broken `spawn EINVAL` on Node 20+/24.
 * Asks for the keystore password first, then Gradle build + apksigner.
 */
import { spawnSync } from 'child_process';
import fs from 'fs';
import path from 'path';
import readline from 'readline';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(__dirname, '..');
const KEYSTORE = path.join(ROOT, 'android.keystore');

const TEMURIN_17 = 'C:\\Program Files\\Eclipse Adoptium\\jdk-17.0.20.101-hotspot';
const ANDROID_HOME =
  process.env.ANDROID_HOME ||
  path.join(process.env.LOCALAPPDATA || '', 'Android', 'Sdk');

function pickJavaHome() {
  if (fs.existsSync(path.join(TEMURIN_17, 'bin', 'java.exe'))) return TEMURIN_17;
  const env = process.env.JAVA_HOME;
  if (env && fs.existsSync(path.join(env, 'bin', 'java.exe')) && !/Android Studio\\jbr/i.test(env)) {
    return env;
  }
  console.error('JDK 17 not found at:', TEMURIN_17);
  process.exit(1);
}

const JAVA_HOME = pickJavaHome();

function ask(prompt) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  return new Promise((resolve) => {
    rl.question(prompt, (answer) => {
      rl.close();
      resolve(answer);
    });
  });
}

function run(cmd, args) {
  console.log(`\n> ${cmd} ${args.join(' ')}`);
  const r = spawnSync(cmd, args, {
    cwd: ROOT,
    stdio: 'inherit',
    shell: true,
    env: {
      ...process.env,
      JAVA_HOME,
      ANDROID_HOME,
      ANDROID_SDK_ROOT: ANDROID_HOME
    }
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

function findBuildTool(exe) {
  const bt = path.join(ANDROID_HOME, 'build-tools');
  if (!fs.existsSync(bt)) return null;
  const versions = fs.readdirSync(bt).sort().reverse();
  for (const v of versions) {
    const p = path.join(bt, v, exe);
    if (fs.existsSync(p)) return p;
  }
  return null;
}

if (!fs.existsSync(KEYSTORE)) {
  console.error('Missing android.keystore — run npm run init first.');
  process.exit(1);
}
if (!fs.existsSync(path.join(ROOT, 'gradlew.bat'))) {
  console.error('Missing Gradle project — run npm run update first.');
  process.exit(1);
}
if (!fs.existsSync(ANDROID_HOME)) {
  console.error(`Android SDK not found at ${ANDROID_HOME}`);
  process.exit(1);
}

console.log('Building Defuse Protocol App Lab APK (Windows Gradle path)…');
console.log(`JAVA_HOME=${JAVA_HOME}`);
console.log(`ANDROID_HOME=${ANDROID_HOME}`);

// Ask BEFORE gradle so the prompt is not buried under build noise / Node warnings.
console.log('\nEnter the same password you used when creating android.keystore.');
const storePass = await ask('Keystore password: ');
if (!storePass) {
  console.error('Password required.');
  process.exit(1);
}
const keyPassRaw = await ask('Key password (Enter = same as keystore): ');
const keyPass = keyPassRaw || storePass;

run(path.join(ROOT, 'gradlew.bat'), ['assembleRelease', '--no-daemon']);

const releaseDir = path.join(ROOT, 'app', 'build', 'outputs', 'apk', 'release');
const unsigned = path.join(releaseDir, 'app-release-unsigned.apk');
const aligned = path.join(ROOT, 'app-release-unsigned-aligned.apk');
const signed = path.join(ROOT, 'app-release-signed.apk');

let inputApk = unsigned;
if (!fs.existsSync(inputApk)) {
  const alt = path.join(releaseDir, 'app-release.apk');
  if (fs.existsSync(alt)) inputApk = alt;
  else {
    console.error('Could not find release APK under app/build/outputs/apk/release/');
    if (fs.existsSync(releaseDir)) console.error(fs.readdirSync(releaseDir).join(', '));
    process.exit(1);
  }
}

console.log(`\nBuilt: ${inputApk}`);

const zipalign = findBuildTool('zipalign.exe');
const apksigner = findBuildTool('apksigner.bat');

if (zipalign) {
  run(zipalign, ['-f', '-p', '4', inputApk, aligned]);
} else {
  fs.copyFileSync(inputApk, aligned);
}

if (!apksigner) {
  console.error('apksigner not found in Android SDK build-tools.');
  process.exit(1);
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

console.log(`\nDone.\nSigned APK:\n  ${signed}`);
console.log('Upload that file in Meta Developer Dashboard (App Lab).');
