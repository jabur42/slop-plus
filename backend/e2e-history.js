// Teste: histórico/retomada independente do torrent + limpeza de cache ao trocar de vídeo.
// Usa torrents de domínio público (Big Buck Bunny e Sintel) num backend separado (porta 8790).
import http from 'node:http';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawn } from 'node:child_process';

const BBB = 'dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c';
const SINTEL = '08ada5a7a6183aae1e09d831df6748d566095a10';
const manifest = { id: 'test.pd', version: '1.0.0', name: 'Teste', resources: ['stream'], types: ['movie'], idPrefixes: ['tt'], catalogs: [] };
const addon = http.createServer((req, res) => {
  res.setHeader('Content-Type', 'application/json');
  if (req.url.startsWith('/manifest.json')) return res.end(JSON.stringify(manifest));
  res.end(JSON.stringify({ streams: [
    { name: 'T\n1080p', title: 'BBB A\n👤 99', infoHash: BBB, fileIdx: 1 },
    { name: 'T\n720p', title: 'Sintel\n👤 50', infoHash: SINTEL },
  ] }));
}).listen(7001);

const WORK = path.join(os.tmpdir(), 'slop-plus-8790');
const be = spawn(process.execPath, ['server.js'], { env: { ...process.env, SLOP_PORT: '8790', SLOP_EXTRA_ADDON: 'http://127.0.0.1:7001/manifest.json' }, stdio: ['ignore', 'pipe', 'pipe'] });
be.stdout.on('data', (d) => process.stdout.write('  [be] ' + d));
be.stderr.on('data', (d) => process.stdout.write('  [be!] ' + d));
const B = 'http://127.0.0.1:8790';
const j = async (p) => (await fetch(B + p, { signal: AbortSignal.timeout(300000) })).json();
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const caps = 'hevc=0&ac3=0&maxh=1080';
const ls = () => fs.readdirSync(WORK).join(', ');
let ok = true;
const check = (cond, msg) => { console.log(cond ? 'OK  ' : 'FALHA', msg); ok = ok && cond; };
try {
  await sleep(6000);
  const vid = 'tt1254207';
  const meta = `metaId=${vid}&type=movie&name=Big%20Buck%20Bunny&poster=x&bg=y&logo=z&label=`;
  // 1) salva progresso e confere fileira
  await j(`/api/progress?vid=${vid}&pos=200&dur=600&${meta}`);
  const c = (await j('/api/continue')).row;
  check(c && c.items[0].vid === vid && Math.abs(c.items[0].progress - 0.333) < 0.01, `continuar assistindo: ${JSON.stringify(c?.items[0])}`);
  const home = await j('/api/home');
  check(home.rows[0].kind === 'continue', `home: 1ª fileira = "${home.rows[0].title}"`);

  // 2) play com resume num torrent qualquer -> começa em 195s
  const st = (await j(`/api/streams?type=movie&id=${vid}`)).streams.filter((x) => x.addon === 'Teste');
  const a = st.find((x) => x.release === 'BBB A');
  const s2 = st.find((x) => x.release === 'Sintel');
  const p1 = await j(`/api/play?key=${a.key}&${caps}&vid=${vid}&resume=1`);
  check(p1.resume === 195 && (p1.mode === 'direct' || p1.offset === 195), `retomada: mode=${p1.mode} resume=${p1.resume} offset=${p1.offset}`);
  await sleep(3000);
  console.log('     cache com BBB:', ls());

  // 3) troca para outro torrent: cache do BBB deve sumir
  const p2 = await j(`/api/play?key=${s2.key}&${caps}&vid=other`);
  check(p2.resume === 0, `outro vídeo sem histórico começa do 0 (resume=${p2.resume})`);
  await sleep(3000);
  const now = ls();
  console.log('     cache depois de trocar:', now);
  check(!now.includes('Big Buck Bunny'), 'cache do vídeo anterior apagado');

  // 4) parar limpa tudo
  await j('/api/stop');
  await sleep(4000);
  check(fs.readdirSync(WORK).length === 0, `após parar, cache vazio (${ls() || 'nada'})`);

  // 5) terminar o filme tira da fileira e zera a posição
  await j(`/api/progress?vid=${vid}&pos=590&dur=600&${meta}`);
  check(!(await j('/api/continue')).row, 'filme terminado sai do "Continuar assistindo"');
} catch (e) { ok = false; console.log('ERRO:', e.message); }
console.log(ok ? '\nTUDO OK' : '\nHOUVE FALHAS');
be.kill(); addon.close(); process.exit(ok ? 0 : 1);
