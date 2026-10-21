/**
 * Print the SHA-256 fingerprint of android.keystore for Digital Asset Links.
 */
import { spawnSync } from 'child_process';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import readline from 'readline';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(__dirname, '..');
const KEYSTORE = path.join(ROOT, 'android.keystore');

if (!fs.existsSync(KEYSTORE)) {
  console.error('No android.keystore — run npm run init first.');
  process.exit(1);
}

const temurin = 'C:\\Program Files\\Eclipse Adoptium\\jdk-17.0.20.101-hotspot\\bin\\keytool.exe';
const keytool = fs.existsSync(temurin)
  ? temurin
  : process.env.JAVA_HOME
    ? path.join(process.env.JAVA_HOME, 'bin', process.platform === 'win32' ? 'keytool.exe' : 'keytool')
    : 'keytool';

function ask(prompt) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  return new Promise((resolve) => {
    rl.question(prompt, (answer) => {
      rl.close();
      resolve(answer);
    });
  });
}

const password = await ask('Enter keystore password: ');
if (!password) {
  console.error('Password required.');
  process.exit(1);
}

// No shell:true — paths with spaces (Program Files) break under cmd otherwise.
const r = spawnSync(
  keytool,
  [
    '-list',
    '-v',
    '-keystore', KEYSTORE,
    '-alias', 'android',
    '-storepass', password
  ],
  { encoding: 'utf8', shell: false }
);

const out = `${r.stdout || ''}\n${r.stderr || ''}`;
const m = out.match(/SHA256:\s*([0-9A-Fa-f:]+)/i);
if (!m) {
  console.log(out);
  console.error('\nCould not parse SHA-256. Wrong password, or keystore alias is not "android".');
  process.exit(1);
}

const fp = m[1].toUpperCase();
console.log('\nSHA-256 fingerprint:\n');
console.log(fp);
console.log(`
Put this into public/.well-known/assetlinks.json as sha256_cert_fingerprints[0],
then deploy Pages so Meta can verify:

  https://sosgit-app.github.io/defuse-protocol/.well-known/assetlinks.json

Also:
  bubblewrap fingerprint add ${fp}
`);
