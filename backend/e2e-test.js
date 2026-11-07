// Teste ponta a ponta com Big Buck Bunny (domÃ­nio pÃºblico) num backend separado (porta 8790).
import http from 'node:http';
import { spawn } from 'node:child_process';

const manifest = { id: 'test.bbb', version: '1.0.0', name: 'Teste BBB', resources: ['stream'], types: ['movie'], idPrefixes: ['tt'], catalogs: [] };
const addon = http.createServer((req, res) => {
  res.setHeader('Content-Type', 'application/json');
  if (req.url.startsWith('/manifest.json')) return res.end(JSON.stringify(manifest));
  res.end(JSON.stringify({ streams: [{ name: 'Teste\n1080p', title: 'Big Buck Bunny\nðŸ‘¤ 99 ðŸ’¾ 263 MB âš™ï¸ local', infoHash: 'dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c', fileIdx: 1 }] }));
}).listen(7001);

const be = spawn(process.execPath, ['server.js'], { env: { ...process.env, SLOP_PORT: '8790', SLOP_EXTRA_ADDON: 'http://127.0.0.1:7001/manifest.json' }, stdio: ['ignore', 'pipe', 'pipe'] });
be.stdout.on('data', (d) => process.stdout.write('  [be] ' + d));
be.stderr.on('data', (d) => process.stdout.write('  [be!] ' + d));
const B = 'http://127.0.0.1:8790';
const j = async (p, ms = 300000) => (await fetch(B + p, { signal: AbortSignal.timeout(ms) })).json();
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const caps = 'hevc=0&hevc10=0&ac3=0&eac3=0&maxh=1080';
try {
  await sleep(6000);
  const st = await j('/api/streams?type=movie&id=tt1254207');
  const bbb = st.streams.find((x) => x.addon === 'Teste BBB');
  console.log('stream:', bbb.quality, bbb.peers, bbb.size);
  let t0 = Date.now();
  const poll = setInterval(async () => { try { const s = await j('/api/status', 3000); console.log(`  status: ${s.phase} peers=${s.peers} ${s.speed}KB/s ready=${s.ready}s`); } catch {} }, 3000);
  const p1 = await j(`/api/play?key=${bbb.key}&${caps}&audio=por`);
  console.log(`play #1 em ${(Date.now() - t0) / 1000}s:`, p1.mode, p1.format, 'offset', p1.offset, 'dur', p1.duration, 'audios', JSON.stringify(p1.audios), 'audio', p1.audio, 'subs', p1.subtitles.length);
  const pl = await (await fetch(p1.url)).text();
  console.log('playlist segs:', (pl.match(/#EXTINF/g) || []).length);
  const seg = await fetch(new URL(pl.split('\n').find((l) => l.endsWith('.ts')), p1.url));
  console.log('seg0:', seg.status, (await seg.arrayBuffer()).byteLength, 'bytes');
  // Seek para 5 min com a outra faixa de Ã¡udio (reinicia a conversÃ£o, reaproveitando o torrent)
  t0 = Date.now();
  const other = p1.audios.find((a) => a.n !== p1.audio) || p1.audios[0];
  const p2 = await j(`/api/play?key=${bbb.key}&${caps}&start=300&audio=${other.n}`);
  console.log(`play #2 (seek 300s, Ã¡udio ${other.n}) em ${(Date.now() - t0) / 1000}s:`, p2.mode, 'offset', p2.offset, 'audio', p2.audio, p2.url.split('/').slice(-2).join('/'));
  const old = await fetch(p1.url); console.log('playlist antiga agora:', old.status);
  clearInterval(poll);
  const s = await j('/api/status'); console.log('status final:', JSON.stringify(s));
  if (p1.subtitles.length) { const c = await j('/api/subs?u=' + encodeURIComponent(p1.subtitles[0].url)); console.log('cues:', c.cues.length, JSON.stringify(c.cues[0])); }
  // Direto: com HEVC/AC3 "suportados" e vÃ­deo h264 o modo continua HLS porque o BBB tem Ã¡udio mp3+ac3? confere decisÃ£o
  const t3 = Date.now();
  const p3 = await j(`/api/play?key=${bbb.key}&hevc=0&maxh=720&start=60&audio=1`);
  console.log(`transcode (1080p -> 720p via NVENC) em ${(Date.now() - t3) / 1000}s:`, p3.mode, 'offset', p3.offset);
  const pl3 = await (await fetch(p3.url)).text();
  console.log('playlist #3:', pl3.split('\n').filter((l) => l.startsWith('#EXTINF')).join(' '));
  await j('/api/stop');
} catch (e) { console.log('FALHOU:', e.message); }
be.kill(); addon.close(); process.exit(0);

