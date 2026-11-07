// Importa os addons da sua conta Stremio para o config.json.
// A senha é usada só para o login e não é salva.
import fs from 'node:fs';
import path from 'node:path';
import readline from 'node:readline';
import { fileURLToPath } from 'node:url';

const cfgPath = path.join(path.dirname(fileURLToPath(import.meta.url)), 'config.json');
const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
const ask = (q, hidden = false) => new Promise((resolve) => {
  if (hidden) {
    const orig = rl._writeToOutput;
    rl._writeToOutput = (str) => { if (str.startsWith(q)) orig.call(rl, str); else orig.call(rl, '*'); };
    rl.question(q, (a) => { rl._writeToOutput = orig; process.stdout.write('\n'); resolve(a); });
  } else rl.question(q, resolve);
});

async function api(method, body) {
  const r = await fetch(`https://api.strem.io/api/${method}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body),
  });
  const d = await r.json();
  if (d.error) throw new Error(d.error.message || JSON.stringify(d.error));
  return d.result;
}

const email = await ask('E-mail do Stremio: ');
const password = await ask('Senha: ', true);
rl.close();
try {
  const { authKey } = await api('login', { type: 'Login', email, password, facebook: false });
  const { addons } = await api('addonCollectionGet', { type: 'AddonCollectionGet', authKey, update: true });
  const urls = addons.map((a) => a.transportUrl).filter((u) => /^https?:\/\//.test(u) && !/127\.0\.0\.1|localhost/.test(u));
  const cfg = JSON.parse(fs.readFileSync(cfgPath, 'utf8').replace(/^\uFEFF/, ''));
  cfg.addons = [...new Set(urls)];
  fs.writeFileSync(cfgPath, JSON.stringify(cfg, null, 2) + '\n');
  console.log(`\n${cfg.addons.length} addons importados:`);
  addons.forEach((a) => console.log(' -', a.manifest?.name || a.transportUrl));
  console.log('\nReinicie o backend (npm start).');
} catch (e) {
  console.error('Falhou:', e.message);
  process.exit(1);
}
