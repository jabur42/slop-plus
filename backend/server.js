// Backend do Slop+: agrega addons Stremio, baixa torrents (WebTorrent)
// e entrega o vídeo ao Roku (direto ou convertido para HLS com ffmpeg).
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import crypto from 'node:crypto';
import { spawn, execFile, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import WebTorrent from 'webtorrent';
import ffmpegPath from 'ffmpeg-static';
import ffprobeStatic from 'ffprobe-static';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
// config.json é pessoal (fica fora do git); na primeira execução é criado a partir do exemplo
const CONFIG_PATH = path.join(__dirname, 'config.json');
if (!fs.existsSync(CONFIG_PATH)) fs.copyFileSync(path.join(__dirname, 'config.example.json'), CONFIG_PATH);
const config = JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8').replace(/^\uFEFF/, ''));
// Para testes: SLOP_PORT muda a porta e SLOP_EXTRA_ADDON adiciona um addon
if (process.env.SLOP_PORT) config.port = Number(process.env.SLOP_PORT);
if (process.env.SLOP_EXTRA_ADDON) config.addons.push(process.env.SLOP_EXTRA_ADDON);
const PORT = config.port || 8787;
const WORK_DIR = path.join(os.tmpdir(), process.env.SLOP_PORT ? `slop-plus-${PORT}` : 'slop-plus');
const VIDEO_EXT = ['.mkv', '.mp4', '.m4v', '.avi', '.mov', '.wmv', '.ts', '.webm', '.mpg', '.mpeg'];
const TRACKERS = [
  'udp://tracker.opentrackr.org:1337/announce',
  'udp://open.demonii.com:1337/announce',
  'udp://tracker.torrent.eu.org:451/announce',
  'udp://exodus.desync.com:6969/announce',
  'udp://open.stealth.si:80/announce',
  'udp://tracker.openbittorrent.com:6969/announce',
  'udp://explodie.org:6969/announce',
  'udp://tracker.dler.org:6969/announce',
  'https://tracker.tamersunion.org:443/announce',
];

const log = (...a) => console.log(new Date().toLocaleTimeString(), ...a);
const s = (v) => (v === null || v === undefined ? '' : String(v));

// ---------------------------------------------------------------- idiomas
const LANGS = {
  por: 'Português', pob: 'Português (BR)', eng: 'Inglês', spa: 'Espanhol', fre: 'Francês', fra: 'Francês',
  ger: 'Alemão', deu: 'Alemão', ita: 'Italiano', jpn: 'Japonês', kor: 'Coreano', chi: 'Chinês', zho: 'Chinês',
  rus: 'Russo', pol: 'Polonês', ukr: 'Ucraniano', hin: 'Hindi', ara: 'Árabe', tur: 'Turco', dut: 'Holandês',
  nld: 'Holandês', swe: 'Sueco', nor: 'Norueguês', dan: 'Dinamarquês', fin: 'Finlandês', cze: 'Tcheco',
  hun: 'Húngaro', gre: 'Grego', heb: 'Hebraico', tha: 'Tailandês', vie: 'Vietnamita', ind: 'Indonésio',
  rum: 'Romeno', ron: 'Romeno', bul: 'Búlgaro', hrv: 'Croata', srp: 'Sérvio', und: 'Desconhecido',
};
const LANG_ALIAS = { pt: 'por', 'pt-br': 'pob', ptbr: 'pob', en: 'eng', es: 'spa', fr: 'fre', de: 'ger', it: 'ita', ja: 'jpn', ko: 'kor', zh: 'chi', ru: 'rus', pl: 'pol' };
const normLang = (l) => { const x = s(l).toLowerCase(); return LANG_ALIAS[x] || x || 'und'; };
const langName = (l) => LANGS[normLang(l)] || s(l).toUpperCase() || 'Desconhecido';
// Bandeiras dos títulos do Torrentio -> idioma
const FLAG_LANG = { GB: 'EN', US: 'EN', BR: 'PT-BR', PT: 'PT', ES: 'ES', MX: 'ES-LA', FR: 'FR', DE: 'DE', IT: 'IT', RU: 'RU', JP: 'JA', KR: 'KO', CN: 'ZH', TW: 'ZH', IN: 'HI', PL: 'PL', UA: 'UK', NL: 'NL', TR: 'TR', CZ: 'CS', HU: 'HU', GR: 'EL', IL: 'HE', TH: 'TH', VN: 'VI', SA: 'AR', SE: 'SV', NO: 'NO', DK: 'DA', FI: 'FI', RO: 'RO', BG: 'BG', HR: 'HR', RS: 'SR', ID: 'ID' };

// ---------------------------------------------------------------- addons
let addons = []; // [{ base, manifest }]

async function fetchJson(url, ms = 15000) {
  const r = await fetch(url, { signal: AbortSignal.timeout(ms) });
  if (!r.ok) throw new Error(`HTTP ${r.status} em ${url}`);
  return r.json();
}

async function loadAddons() {
  const list = await Promise.all(config.addons.map(async (u) => {
    try {
      return { base: u.replace(/\/manifest\.json.*$/, ''), manifest: await fetchJson(u) };
    } catch (e) {
      log('Addon falhou:', u, e.message);
      return null;
    }
  }));
  addons = list.filter(Boolean);
  log('Addons carregados:', addons.map((a) => a.manifest.name).join(', ') || 'nenhum');
}

function supports(addon, resource, type, id) {
  const m = addon.manifest;
  for (const r of m.resources || []) {
    const obj = typeof r === 'object' ? r : null;
    if ((obj ? obj.name : r) !== resource) continue;
    const types = (obj && obj.types) || m.types || [];
    const prefixes = (obj && obj.idPrefixes) || m.idPrefixes;
    if (!types.includes(type)) continue;
    if (prefixes && id && !prefixes.some((p) => id.startsWith(p))) continue;
    return true;
  }
  return false;
}

const metahubLogo = (id) => (/^tt\d+$/.test(s(id)) ? `https://images.metahub.space/logo/medium/${id}/img` : '');
const mapItem = (m) => ({
  id: s(m.id), type: s(m.type), name: s(m.name), poster: s(m.poster),
  background: s(m.background || m.poster), description: s(m.description), logo: s(m.logo) || metahubLogo(m.id),
  info: [s(m.releaseInfo || m.year), m.imdbRating ? `IMDb ${m.imdbRating}` : ''].filter(Boolean).join('   ·   '),
});

function catalogsWith(filter) {
  const out = [];
  for (const a of addons) {
    for (const c of a.manifest.catalogs || []) {
      if (!['movie', 'series'].includes(c.type)) continue;
      if (filter(c)) out.push({ a, c });
    }
  }
  return out;
}

const ROW_NAMES = { top: 'Em alta', imdbRating: 'Mais bem avaliados', year: 'Lançamentos', featured: 'Destaques' };
async function fetchRow(a, c, extra = '') {
  try {
    const d = await fetchJson(`${a.base}/catalog/${c.type}/${encodeURIComponent(c.id)}${extra}.json`);
    const items = (d.metas || []).slice(0, 40).map(mapItem).filter((i) => i.id);
    if (!items.length) return null;
    const kind = c.type === 'movie' ? 'Filmes' : 'Séries';
    const name = ROW_NAMES[c.id] || c.name || c.id;
    return { title: extra ? `${kind}` : `${name}: ${kind}`, items };
  } catch {
    return null;
  }
}

let homeCache = { at: 0, rows: null };
async function getHome() {
  if (homeCache.rows && Date.now() - homeCache.at < 30 * 60e3) return homeCache.rows;
  const jobs = catalogsWith((c) => !(c.extra || []).some((e) => e.isRequired) && !(c.extraRequired || []).length);
  const rows = (await Promise.all(jobs.slice(0, 14).map(({ a, c }) => fetchRow(a, c)))).filter(Boolean);
  homeCache = { at: Date.now(), rows };
  return rows;
}

async function search(q) {
  const jobs = catalogsWith((c) => (c.extra || []).some((e) => e.name === 'search') || (c.extraSupported || []).includes('search'));
  const extra = `/search=${encodeURIComponent(q)}`;
  return (await Promise.all(jobs.map(({ a, c }) => fetchRow(a, c, extra)))).filter(Boolean);
}

function formatMeta(m) {
  const seasons = new Map();
  for (const v of m.videos || []) {
    const sn = Number(v.season ?? 0);
    if (!seasons.has(sn)) seasons.set(sn, []);
    const ep = Number(v.episode ?? v.number ?? 0);
    seasons.get(sn).push({
      id: s(v.id), ep, title: s(v.title || v.name || `Episódio ${ep}`),
      thumb: s(v.thumbnail), overview: s(v.overview || v.description),
      released: s(v.released).slice(0, 10),
    });
  }
  const list = [...seasons.entries()]
    .sort((x, y) => (x[0] === 0) - (y[0] === 0) || x[0] - y[0])
    .map(([season, eps]) => ({
      label: season === 0 ? 'Especiais' : `Temporada ${season}`,
      short: season === 0 ? 'Especiais' : `T${season}`,
      episodes: eps.sort((x, y) => x.ep - y.ep),
    }));
  const genres = Array.isArray(m.genres) ? m.genres.slice(0, 3).join(', ') : '';
  return {
    id: s(m.id), type: s(m.type), name: s(m.name), description: s(m.description),
    poster: s(m.poster), background: s(m.background || m.poster), logo: s(m.logo) || metahubLogo(m.id),
    year: s(m.releaseInfo || m.year), genres, runtime: s(m.runtime), rating: s(m.imdbRating),
    cast: Array.isArray(m.cast) ? m.cast.slice(0, 4).join(', ') : '',
    seasons: m.type === 'series' ? list : [],
  };
}

async function getMeta(type, id) {
  for (const a of addons.filter((x) => supports(x, 'meta', type, id))) {
    try {
      const d = await fetchJson(`${a.base}/meta/${type}/${encodeURIComponent(id)}.json`);
      if (d.meta) return formatMeta(d.meta);
    } catch { /* tenta o próximo addon */ }
  }
  throw new Error('Detalhes não encontrados');
}

// ---------------------------------------------------------------- streams (ranking)
// Lê qualidade, peers, tamanho, fonte, idiomas e tags do texto do addon (formato Torrentio e parecidos)
export function parseStream(name, title, filename = '') {
  const all = `${name}\n${title}\n${filename}`;
  const lines = s(title).split('\n').map((x) => x.trim()).filter(Boolean);
  let res = 0;
  let quality = 'SD';
  if (/\b(2160p|4k|uhd)\b/i.test(all)) { res = 2160; quality = '4K'; }
  else if (/\b1080p\b/i.test(all)) { res = 1080; quality = '1080p'; }
  else if (/\b720p\b/i.test(all)) { res = 720; quality = '720p'; }
  else if (/\b(576p|480p|360p|dvdrip|bdrip|brrip|webrip|hdtv|hdrip|xvid|sd)\b/i.test(all)) { res = 480; quality = 'SD'; }
  const cam = /\b(cam|camrip|hdcam|ts|telesync|hdts|tc|telecine|scr|screener)\b/i.test(`${name}\n${lines[0] || ''}`);
  if (cam) { res = 100; quality = 'CAM'; }
  const peers = Number((/👤\s*(\d+)/u.exec(all) || [])[1] || 0);
  const size = ((/💾\s*([\d.,]+\s*[KMGT]i?B)/iu.exec(all) || [])[1] || '').replace(/\s+/, ' ');
  const source = ((/⚙️?\s*([^\n]+)/u.exec(all) || [])[1] || '').trim();
  const langs = [...new Set([...all.matchAll(/([\u{1F1E6}-\u{1F1FF}]{2})/gu)].map((m) => {
    const cc = [...m[1]].map((c) => String.fromCharCode(c.codePointAt(0) - 0x1F1E6 + 65)).join('');
    return FLAG_LANG[cc] || cc;
  }))];
  if (/multi\s*audio/i.test(all)) langs.unshift('Multi');
  else if (/dual\s*audio/i.test(all)) langs.unshift('Dual');
  const tags = [];
  const t = (re, label) => { if (re.test(all) && !tags.includes(label)) tags.push(label); };
  t(/\bDV\b|dolby.?vision/i, 'DV');
  t(/HDR10\+/i, 'HDR10+');
  if (!tags.includes('HDR10+')) t(/\bHDR(10)?\b/i, 'HDR');
  t(/\b3D\b/, '3D');
  t(/\b(x265|h\.?265|hevc)\b/i, 'HEVC');
  t(/\b(x264|h\.?\s?264|avc)\b/i, 'H.264');
  t(/\bremux\b/i, 'REMUX');
  t(/\batmos\b/i, 'Atmos');
  t(/\b(10.?bit)\b/i, '10-bit');
  const isHevc = tags.includes('HEVC');
  const hdr = tags.some((x) => ['DV', 'HDR', 'HDR10+'].includes(x));
  // Arquivo dentro do torrent (2ª linha em packs de série) ou nome do release
  const release = lines[0] || s(name);
  const file = lines.length > 1 && !/^👤/u.test(lines[1]) ? lines[1].split('/').pop() : '';
  return { res, quality, peers, size, source, langs, tags, release, file, isHevc, hdr, is3d: tags.includes('3D') };
}

// Qualidade primeiro; dentro da mesma qualidade, mais peers primeiro. 3D vai pro fim do grupo.
export function rankStreams(list) {
  return list.sort((a, b) => (b.res - a.res) || (a.is3d - b.is3d) || (b.peers - a.peers));
}

const streamCache = new Map(); // key -> { type, id, infoHash, fileIdx, url, trackers, title }
async function getStreams(type, id) {
  if (streamCache.size > 3000) streamCache.clear();
  const lists = await Promise.all(addons.filter((a) => supports(a, 'stream', type, id)).map(async (a) => {
    try {
      const d = await fetchJson(`${a.base}/stream/${type}/${encodeURIComponent(id)}.json`, 25000);
      return (d.streams || []).filter((st) => st.infoHash || /^https?:/.test(st.url || '')).map((st) => {
        const key = crypto.randomBytes(6).toString('hex');
        const info = parseStream(s(st.name), s(st.title || st.description), s(st.behaviorHints?.filename));
        streamCache.set(key, {
          type, id,
          infoHash: s(st.infoHash).toLowerCase(),
          fileIdx: Number.isInteger(st.fileIdx) ? st.fileIdx : -1,
          url: s(st.url),
          trackers: (st.sources || []).filter((x) => x.startsWith('tracker:')).map((x) => x.slice(8)),
        });
        return { key, addon: s(a.manifest.name), ...info };
      });
    } catch (e) {
      log('Streams falhou em', a.manifest.name, e.message);
      return [];
    }
  }));
  return rankStreams(lists.flat()).map(({ is3d, ...rest }) => rest);
}

// ---------------------------------------------------------------- legendas externas
async function getSubtitles(type, id) {
  const subs = [];
  await Promise.all(addons.filter((a) => supports(a, 'subtitles', type, id)).map(async (a) => {
    try {
      const d = await fetchJson(`${a.base}/subtitles/${type}/${encodeURIComponent(id)}.json`, 10000);
      subs.push(...(d.subtitles || []));
    } catch { /* sem legendas desse addon */ }
  }));
  const order = ['pob', 'por', 'eng', 'spa'];
  const byLang = new Map();
  for (const x of subs) {
    let l = normLang(x.lang);
    if (l === 'pob') l = 'por'; // o OpenSubtitles marca PT-BR como "pob"
    if (!byLang.has(l)) byLang.set(l, []);
    byLang.get(l).push(x);
  }
  const langs = [...byLang.keys()].sort((a, b) => {
    const ia = order.indexOf(a); const ib = order.indexOf(b);
    return (ia < 0 ? 99 : ia) - (ib < 0 ? 99 : ib) || langName(a).localeCompare(langName(b));
  });
  const out = [];
  for (const l of langs) {
    const max = l === 'por' ? 6 : ['eng', 'spa'].includes(l) ? 3 : 1;
    byLang.get(l).slice(0, max).forEach((x, i, arr) => {
      knownSubUrls.add(s(x.url));
      out.push({ url: s(x.url), lang: l, label: arr.length > 1 ? `${langName(l)} ${i + 1}` : langName(l) });
    });
  }
  return out.slice(0, 30);
}

// SRT/VTT -> [[inicio, fim, texto]] em segundos, já deslocado por "off"
export function parseCues(txt, off = 0) {
  const cues = [];
  const toSec = (h, m, sec, ms) => Number(h || 0) * 3600 + Number(m) * 60 + Number(sec) + Number(ms) / 1000;
  const blocks = txt.replace(/\r/g, '').split(/\n\s*\n/);
  const re = /(?:(\d+):)?(\d{1,2}):(\d{2})[,.](\d{1,3})\s*-->\s*(?:(\d+):)?(\d{1,2}):(\d{2})[,.](\d{1,3})/;
  for (const b of blocks) {
    const lines = b.split('\n');
    const i = lines.findIndex((l) => re.test(l));
    if (i < 0) continue;
    const m = re.exec(lines[i]);
    const st = toSec(m[1], m[2], m[3], m[4].padEnd(3, '0')) - off;
    const en = toSec(m[5], m[6], m[7], m[8].padEnd(3, '0')) - off;
    const text = lines.slice(i + 1).join('\n')
      .replace(/<[^>]+>/g, '').replace(/\{\\[^}]*\}/g, '').replace(/&nbsp;/g, ' ').trim();
    if (!text || en <= 0) continue;
    cues.push([Math.max(0, Math.round(st * 1000) / 1000), Math.round(en * 1000) / 1000, text]);
  }
  return cues.sort((a, b) => a[0] - b[0]);
}

const subCache = new Map();
// Só baixa legendas cujo endereço veio de um addon (evita usar o backend como proxy para qualquer site)
const knownSubUrls = new Set();
async function getCues(url, off) {
  if (!/^https?:\/\//.test(url) || !knownSubUrls.has(url)) throw new Error('Legenda inválida');
  let txt = subCache.get(url);
  if (!txt) {
    const r = await fetch(url, { signal: AbortSignal.timeout(15000) });
    const buf = Buffer.from(await r.arrayBuffer());
    if (buf.length > 5e6) throw new Error('Legenda grande demais');
    txt = new TextDecoder('utf-8').decode(buf);
    if (txt.includes('\uFFFD')) txt = new TextDecoder('windows-1252').decode(buf); // legendas antigas em Latin-1
    txt = txt.replace(/^\uFEFF/, '');
    if (subCache.size > 50) subCache.clear();
    subCache.set(url, txt);
  }
  return parseCues(txt, off);
}

// ---------------------------------------------------------------- encoder
// Usa a placa NVIDIA (NVENC) se disponível: converte 4K/HEVC bem mais rápido que a CPU.
let hwEncoder = null;
function detectEncoder() {
  const r = spawnSync(ffmpegPath, ['-hide_banner', '-loglevel', 'error', '-f', 'lavfi', '-i', 'testsrc2=s=640x360:d=0.5',
    '-c:v', 'h264_nvenc', '-f', 'null', '-'], { windowsHide: true, timeout: 20000 });
  hwEncoder = r.status === 0 ? 'nvenc' : null;
  log('Encoder de vídeo:', hwEncoder ? 'NVIDIA NVENC (GPU)' : 'libx264 (CPU)');
}

// ---------------------------------------------------------------- reprodução
let client = null;
function torrentClient() {
  if (!client) {
    client = new WebTorrent({ maxConns: 100 });
    client.on('error', (e) => log('WebTorrent:', e.message));
  }
  return client;
}
// session: { id, key, torrent, file, probe, input, ext, ffmpeg, dir, gen, phase, hlsStart, result }
let session = null;

function openTorrent(sess, st) {
  return new Promise((resolve, reject) => {
    const tr = [...new Set([...TRACKERS, ...st.trackers])].map((t) => '&tr=' + encodeURIComponent(t)).join('');
    let torrent;
    try {
      torrent = torrentClient().add(`magnet:?xt=urn:btih:${st.infoHash}${tr}`, { path: WORK_DIR, deselect: true });
    } catch (e) {
      return reject(e);
    }
    sess.torrent = torrent;
    sess.phase = 'Procurando peers';
    const timer = setTimeout(() => reject(new Error('Torrent sem fontes (nenhum peer respondeu em 90s)')), 90000);
    torrent.on('wire', () => { if (!torrent.ready) sess.phase = 'Baixando informações do torrent'; });
    torrent.on('error', (e) => { clearTimeout(timer); reject(e); });
    torrent.on('ready', () => {
      clearTimeout(timer);
      const isVideo = (f) => VIDEO_EXT.includes(path.extname(f.name).toLowerCase());
      let file = st.fileIdx >= 0 ? torrent.files[st.fileIdx] : null;
      if (!file || !isVideo(file)) file = torrent.files.filter(isVideo).sort((x, y) => y.length - x.length)[0];
      if (!file) return reject(new Error('Nenhum vídeo dentro do torrent'));
      try { torrent.deselect(0, torrent.pieces.length - 1, false); } catch { /* ok */ }
      torrent.files.forEach((f) => f !== file && f.deselect());
      file.select();
      sess.file = file;
      log(`Torrent pronto: ${file.name} (${(file.length / 1e9).toFixed(2)} GB, ${torrent.numPeers} peers)`);
      resolve(file);
    });
  });
}

function ffprobe(input) {
  return new Promise((resolve, reject) => {
    execFile(ffprobeStatic.path, ['-v', 'error', '-probesize', '8M', '-analyzeduration', '6M',
      '-show_streams', '-show_format', '-of', 'json', input],
    { timeout: 150000, maxBuffer: 20 * 1024 * 1024 },
    (err, out) => {
      if (err) return reject(new Error('Não foi possível ler o vídeo'));
      try { resolve(JSON.parse(out)); } catch { reject(new Error('Resposta inválida do ffprobe')); }
    });
  });
}

const CH = { 1: 'Mono', 2: 'Estéreo', 6: '5.1', 8: '7.1' };
function audioList(probe) {
  return (probe.streams || []).filter((x) => x.codec_type === 'audio').map((x, i) => {
    const lang = normLang(x.tags?.language);
    const extra = [s(x.codec_name).toUpperCase().replace('EAC3', 'E-AC3'), CH[x.channels] || (x.channels ? `${x.channels}ch` : '')].filter(Boolean).join(' ');
    const title = s(x.tags?.title).slice(0, 40);
    return { index: x.index, n: i, lang, label: `${lang === 'und' ? `Faixa ${i + 1}` : langName(lang)}${title ? ` · ${title}` : ''} (${extra})`, codec: x.codec_name, def: !!x.disposition?.default };
  });
}

function pickAudio(audios, pref) {
  const p = normLang(pref);
  return audios.find((a) => a.n === Number(pref) && /^\d+$/.test(s(pref)))
    || (p && p !== 'und' && audios.find((a) => a.lang === p || (p === 'por' && a.lang === 'pob')))
    || audios.find((a) => a.def) || audios[0];
}

function hlsFrames(txt) { return [...txt.matchAll(/#EXTINF:([\d.]+)/g)].reduce((t, m) => t + Number(m[1]), 0); }

function startHls(sess, { copyVideo, audio, start, maxH, hevcCopy }) {
  if (sess.ffmpeg && sess.ffmpeg.exitCode === null) sess.ffmpeg.kill('SIGKILL');
  if (sess.dir) { const old = sess.dir; setTimeout(() => fs.rm(old, { recursive: true, force: true }, () => {}), 3000); }
  sess.gen = (sess.gen || 0) + 1;
  const dir = path.join(WORK_DIR, `hls-${sess.id}-${sess.gen}`);
  fs.mkdirSync(dir, { recursive: true });
  sess.dir = dir;
  sess.hlsStart = start;
  const playlist = path.join(dir, 'index.m3u8');
  const v = (sess.probe.streams || []).find((x) => x.codec_type === 'video');
  const hdr = ['smpte2084', 'arib-std-b67'].includes(s(v?.color_transfer));

  const args = ['-hide_banner', '-loglevel', 'error', '-nostdin'];
  if (!copyVideo && hwEncoder) args.push('-hwaccel', 'cuda');
  if (start > 0) args.push('-ss', String(start));
  args.push('-i', sess.input, '-map', '0:v:0');
  if (audio) args.push('-map', `0:${audio.index}`);
  if (copyVideo) {
    args.push('-c:v', 'copy');
    if (hevcCopy) args.push('-tag:v', 'hvc1');
  } else {
    const h = Math.min(maxH, 1080);
    const vf = hdr
      ? `zscale=w=-2:h='min(${h},ih)':t=linear:npl=100,format=gbrpf32le,zscale=p=bt709,tonemap=hable:desat=0,zscale=t=bt709:m=bt709:r=tv,format=yuv420p`
      : `scale=-2:'min(${h},ih)',format=yuv420p`;
    args.push('-vf', vf);
    if (hwEncoder === 'nvenc') {
      args.push('-c:v', 'h264_nvenc', '-preset', 'p4', '-rc', 'vbr', '-cq', '23', '-b:v', '7M', '-maxrate', '10M', '-bufsize', '14M',
        '-profile:v', 'high', '-g', '96', '-forced-idr', '1');
    } else {
      args.push('-c:v', 'libx264', '-preset', 'veryfast', '-crf', '22', '-maxrate', '8M', '-bufsize', '16M', '-profile:v', 'high');
    }
    args.push('-force_key_frames', 'expr:gte(t,n_forced*4)');
  }
  if (audio) args.push('-c:a', 'aac', '-ac', '2', '-b:a', '192k');
  args.push('-max_muxing_queue_size', '2048', '-f', 'hls', '-hls_init_time', '2', '-hls_time', '4', '-hls_list_size', '0',
    '-hls_playlist_type', 'event');
  if (hevcCopy) args.push('-hls_segment_type', 'fmp4', '-hls_fmp4_init_filename', 'init.mp4', '-hls_segment_filename', path.join(dir, 'seg%05d.m4s'));
  else args.push('-hls_segment_filename', path.join(dir, 'seg%05d.ts'));
  args.push(playlist);

  log(`HLS a partir de ${Math.round(start)}s: vídeo ${copyVideo ? 'copiado' : `convertido (${hwEncoder || 'cpu'}${hdr ? ', HDR->SDR' : ''})`}, áudio ${audio ? audio.label : 'nenhum'}`);
  sess.phase = copyVideo ? 'Preparando o áudio' : 'Convertendo o vídeo';
  const ff = spawn(ffmpegPath, args, { stdio: ['ignore', 'ignore', 'pipe'], windowsHide: true });
  sess.ffmpeg = ff;
  ff.stderr.on('data', (d) => log('ffmpeg:', d.toString().trim().slice(0, 300)));

  const gen = sess.gen;
  return new Promise((resolve, reject) => {
    const t0 = Date.now();
    const iv = setInterval(() => {
      let txt = '';
      try { txt = fs.readFileSync(playlist, 'utf8'); } catch { /* ainda não existe */ }
      // 2 segmentos (~6s) já bastam para o Roku começar; o resto é gerado durante a reprodução
      if ((txt.match(/#EXTINF/g) || []).length >= 2 || txt.includes('#EXT-X-ENDLIST')) { clearInterval(iv); resolve(); }
      else if (ff.exitCode !== null) { clearInterval(iv); reject(new Error('Falha na conversão do vídeo')); }
      else if (session !== sess || sess.gen !== gen) { clearInterval(iv); reject(new Error('Cancelado')); }
      else if (Date.now() - t0 > 240000) { clearInterval(iv); reject(new Error('Tempo esgotado preparando o vídeo')); }
    }, 400);
  });
}

async function stopSession() {
  const old = session;
  session = null;
  if (!old) return;
  if (old.ffmpeg && old.ffmpeg.exitCode === null) old.ffmpeg.kill('SIGKILL');
  if (old.torrent) {
    await new Promise((r) => {
      const t = setTimeout(r, 5000);
      try { old.torrent.destroy({ destroyStore: true }, () => { clearTimeout(t); r(); }); } catch { r(); }
    });
  }
  if (old.dir) setTimeout(() => fs.rm(old.dir, { recursive: true, force: true }, () => {}), 2000);
  setTimeout(() => sweepWorkDir(), 2500);
  log('Reprodução encerrada');
}

// Apaga da pasta de trabalho tudo que não pertence ao vídeo atual (torrents e HLS antigos)
function sweepWorkDir(beforeNew = false) {
  const keep = new Set();
  if (session?.dir) keep.add(path.basename(session.dir));
  if (session?.torrent?.name) keep.add(session.torrent.name);
  // Torrent novo ainda sem nome: só limpa quando chamado no início do play (antes de baixar algo)
  if (!beforeNew && session && !session.torrent?.name) return;
  let freed = 0;
  for (const name of fs.readdirSync(WORK_DIR)) {
    if (keep.has(name)) continue;
    const p = path.join(WORK_DIR, name);
    try { freed += dirSize(p); fs.rmSync(p, { recursive: true, force: true }); } catch { /* arquivo em uso: tenta na próxima */ }
  }
  if (freed > 1e6) log(`Cache limpo: ${(freed / 1e9).toFixed(2)} GB liberados`);
}

function dirSize(p) {
  const st = fs.statSync(p);
  if (!st.isDirectory()) return st.size;
  return fs.readdirSync(p).reduce((t, n) => t + dirSize(path.join(p, n)), 0);
}

// ---------------------------------------------------------------- histórico (continuar assistindo)
const DATA_DIR = process.env.SLOP_PORT ? WORK_DIR : path.join(process.env.LOCALAPPDATA || __dirname, 'SlopPlus');
const HISTORY_FILE = path.join(DATA_DIR, 'history.json');
// items: por título (metaId) -> último vídeo assistido; positions: por vídeo (filme ou episódio) -> segundos
let history = { items: {}, positions: {} };
function loadHistory() {
  try { history = { items: {}, positions: {}, ...JSON.parse(fs.readFileSync(HISTORY_FILE, 'utf8')) }; } catch { /* primeiro uso */ }
}
let saveTimer = null;
function saveHistory() {
  clearTimeout(saveTimer);
  saveTimer = setTimeout(() => {
    fs.mkdirSync(DATA_DIR, { recursive: true });
    fs.writeFileSync(HISTORY_FILE + '.tmp', JSON.stringify(history));
    fs.renameSync(HISTORY_FILE + '.tmp', HISTORY_FILE);
  }, 500);
}

const isFinished = (pos, dur) => dur > 0 && (pos / dur >= 0.93 || dur - pos < 60);

function saveProgress(q) {
  const vid = s(q.vid).slice(0, 120);
  const metaId = (s(q.metaId) || vid).slice(0, 120);
  const pos = Number(q.pos) || 0;
  const dur = Number(q.dur) || 0;
  if (!vid) throw new Error('vid obrigatório');
  if (Object.keys(history.items).length > 500 && !history.items[metaId]) {
    // Limite de títulos guardados: remove o mais antigo
    const oldest = Object.values(history.items).sort((a, b) => a.at - b.at)[0];
    delete history.items[oldest.metaId];
  }
  if (isFinished(pos, dur)) {
    delete history.positions[vid];
    if (history.items[metaId]?.vid === vid) delete history.items[metaId];
  } else if (pos >= 20) {
    const at = Date.now();
    history.positions[vid] = { pos, dur, at };
    const t = (v, max = 300) => s(v).slice(0, max);
    history.items[metaId] = {
      metaId, vid, type: t(q.type, 10), name: t(q.name, 200), poster: t(q.poster), bg: t(q.bg), logo: t(q.logo), label: t(q.label, 200), pos, dur, at,
    };
    // Mantém só os 1000 vídeos mais recentes
    const keys = Object.keys(history.positions);
    if (keys.length > 1000) keys.sort((a, b) => history.positions[a].at - history.positions[b].at).slice(0, keys.length - 1000).forEach((k) => delete history.positions[k]);
  }
  saveHistory();
}

function continueRow() {
  const items = Object.values(history.items).sort((a, b) => b.at - a.at).slice(0, 20).map((h) => {
    const left = Math.max(1, Math.round((h.dur - h.pos) / 60));
    return {
      id: h.metaId, type: h.type, name: h.name, poster: h.poster, background: h.bg, logo: h.logo, description: '',
      info: [h.label, `faltam ${left} min`].filter(Boolean).join('   ·   '),
      vid: h.vid, label: h.label, progress: h.dur > 0 ? Math.round((h.pos / h.dur) * 1000) / 1000 : 0,
    };
  });
  return items.length ? { title: 'Continuar assistindo', kind: 'continue', items } : null;
}

// opts: { audio (idioma ou nº da faixa), start (s), caps: { hevc, ac3, eac3, maxh } }
async function play(key, opts) {
  const st = streamCache.get(key);
  if (!st) throw new Error('Opção expirou, volte e escolha de novo');
  const caps = opts.caps;
  let sess = session;

  if (!sess || sess.key !== key) {
    await stopSession();
    sess = { id: crypto.randomBytes(5).toString('hex'), key, phase: 'Conectando', gen: 0 };
    session = sess;
    sess.subsPromise = getSubtitles(st.type, st.id).catch(() => []);
    sweepWorkDir(true); // novo vídeo: apaga o cache do anterior
    if (st.infoHash) {
      log('Abrindo torrent', st.infoHash);
      const file = await openTorrent(sess, st);
      sess.input = `http://127.0.0.1:${PORT}/stream/${sess.id}`;
      sess.direct = `/stream/${sess.id}`;
      sess.ext = path.extname(file.name).toLowerCase();
    } else {
      sess.input = sess.direct = st.url;
      sess.ext = path.extname(new URL(st.url).pathname).toLowerCase();
    }
    sess.phase = 'Analisando o vídeo';
    sess.probe = await ffprobe(sess.input);
    if (session !== sess) throw new Error('Cancelado');
    const v = (sess.probe.streams || []).find((x) => x.codec_type === 'video');
    sess.audios = audioList(sess.probe);
    sess.duration = Number(sess.probe.format?.duration || 0);
    log(`Vídeo: ${v?.codec_name} ${v?.profile} ${v?.width}x${v?.height} ${v?.pix_fmt} ${s(v?.color_transfer)} | Áudio: ${sess.audios.map((x) => x.codec).join(', ') || 'nenhum'}`);
  }

  const v = (sess.probe.streams || []).find((x) => x.codec_type === 'video');
  const maxH = caps.maxh || 1080;
  const hdr = ['smpte2084', 'arib-std-b67'].includes(s(v?.color_transfer));
  const h264Ok = v && v.codec_name === 'h264' && (!v.pix_fmt || v.pix_fmt === 'yuv420p') && (v.height || 0) <= maxH + 8;
  const hevcOk = v && caps.hevc && v.codec_name === 'hevc' && !hdr && (v.height || 0) <= maxH + 8
    && (v.pix_fmt === 'yuv420p' || (caps.hevc10 && v.pix_fmt === 'yuv420p10le'));
  const videoOk = h264Ok || hevcOk;
  const okAudio = ['aac', 'mp3', ...(caps.ac3 ? ['ac3'] : []), ...(caps.eac3 ? ['eac3'] : [])];
  const audioOk = !sess.audios.length || sess.audios.every((x) => okAudio.includes(x.codec));
  const containerOk = ['.mp4', '.m4v', '.mkv'].includes(sess.ext);
  const audio = pickAudio(sess.audios, opts.audio);

  // Retomada: posição salva para este filme/episódio (vale para qualquer torrent), voltando 5s para dar contexto
  let startAt = Number(opts.start) || 0;
  let resume = 0;
  const saved = opts.resume && history.positions[s(opts.vid)];
  if (saved && saved.pos > 20) { resume = Math.max(0, saved.pos - 5); startAt = resume; log(`Retomando de ${Math.round(resume)}s`); }

  let result;
  if (videoOk && audioOk && containerOk && opts.force !== 'hls') {
    // Direto: o próprio Roku faz seek e troca de faixa de áudio
    sess.phase = 'Pronto';
    result = { url: sess.direct, format: sess.ext === '.mkv' ? 'mkv' : 'mp4', mode: 'direct', offset: 0 };
    log('Reprodução direta (sem conversão)');
  } else {
    const start = Math.max(0, Math.min(startAt, Math.max(0, sess.duration - 10)));
    await startHls(sess, { copyVideo: videoOk, hevcCopy: videoOk && !h264Ok, audio, start, maxH });
    sess.phase = 'Pronto';
    result = { url: `/hls/${sess.id}-${sess.gen}/index.m3u8`, format: 'hls', mode: 'hls', offset: start };
  }
  result.resume = resume;
  const subs = await sess.subsPromise;
  if (session !== sess) throw new Error('Cancelado');
  Object.assign(result, {
    duration: sess.duration,
    audios: sess.audios.map(({ n, lang, label }) => ({ n, lang, label })),
    audio: audio ? audio.n : -1,
    subtitles: subs,
    video: v ? `${s(v.codec_name).toUpperCase()} ${v.width}x${v.height}` : '',
  });
  sess.result = result;
  return result;
}

// ---------------------------------------------------------------- HTTP
function sendJson(res, obj, code = 200) {
  const body = JSON.stringify(obj);
  res.writeHead(code, { 'Content-Type': 'application/json; charset=utf-8', 'Content-Length': Buffer.byteLength(body) });
  res.end(body);
}

function serveTorrentFile(req, res, file) {
  const size = file.length;
  const ext = path.extname(file.name).toLowerCase();
  const type = ext === '.mkv' ? 'video/x-matroska' : ['.mp4', '.m4v'].includes(ext) ? 'video/mp4' : 'application/octet-stream';
  let start = 0;
  let end = size - 1;
  let status = 200;
  const m = /bytes=(\d*)-(\d*)/.exec(req.headers.range || '');
  if (m) {
    if (m[1] === '' && m[2]) start = Math.max(0, size - Number(m[2]));
    else {
      start = Number(m[1] || 0);
      if (m[2]) end = Math.min(Number(m[2]), size - 1);
    }
    if (start >= size || start > end) {
      res.writeHead(416, { 'Content-Range': `bytes */${size}` });
      return res.end();
    }
    status = 206;
  }
  const headers = { 'Content-Type': type, 'Accept-Ranges': 'bytes', 'Content-Length': end - start + 1 };
  if (status === 206) headers['Content-Range'] = `bytes ${start}-${end}/${size}`;
  res.writeHead(status, headers);
  if (req.method === 'HEAD') return res.end();
  const stream = file.createReadStream({ start, end });
  stream.on('error', () => res.destroy());
  res.on('close', () => stream.destroy());
  stream.pipe(res);
}

function serveHls(res, dirId, name) {
  if (!session || !session.dir || path.basename(session.dir) !== `hls-${dirId}` || !/^(index\.m3u8|init\.mp4|seg\d{5}\.(ts|m4s))$/.test(name)) return sendJson(res, { error: 'not found' }, 404);
  const file = path.join(session.dir, name);
  if (name.endsWith('.m3u8')) {
    let txt;
    try { txt = fs.readFileSync(file, 'utf8'); } catch { return sendJson(res, { error: 'not found' }, 404); }
    // Faz o Roku começar do início em vez do "ao vivo"
    txt = txt.replace('#EXTM3U', '#EXTM3U\n#EXT-X-START:TIME-OFFSET=0,PRECISE=YES');
    res.writeHead(200, { 'Content-Type': 'application/vnd.apple.mpegurl', 'Cache-Control': 'no-cache' });
    return res.end(txt);
  }
  fs.stat(file, (err, st) => {
    if (err) return sendJson(res, { error: 'not found' }, 404);
    const type = name.endsWith('.ts') ? 'video/mp2t' : 'video/mp4';
    res.writeHead(200, { 'Content-Type': type, 'Content-Length': st.size });
    fs.createReadStream(file).pipe(res);
  });
}

function status() {
  const sess = session;
  let ready = 0;
  if (sess?.dir) { try { ready = hlsFrames(fs.readFileSync(path.join(sess.dir, 'index.m3u8'), 'utf8')); } catch { /* ok */ } }
  return {
    active: !!sess, phase: s(sess?.phase), name: s(sess?.file?.name),
    peers: sess?.torrent?.numPeers || 0, speed: Math.round((sess?.torrent?.downloadSpeed || 0) / 1024),
    progress: Math.round((sess?.file?.progress || 0) * 1000) / 10,
    hlsStart: sess?.hlsStart || 0, ready: Math.round(ready * 10) / 10,
    done: sess?.ffmpeg ? sess.ffmpeg.exitCode !== null : false,
  };
}

const parseCaps = (q) => ({
  hevc: q.hevc === '1', hevc10: q.hevc10 === '1', ac3: q.ac3 === '1', eac3: q.eac3 === '1', maxh: Number(q.maxh) || 1080,
});

// Só aceita conexões da rede local (casa) e do próprio PC. Se alguém abrir a porta no roteador
// por engano, acessos vindos da internet são recusados.
export function isLocalAddress(addr) {
  const a = s(addr).replace(/^::ffff:/, '');
  if (a === '::1' || a === '127.0.0.1' || a.startsWith('127.')) return true;
  if (/^10\./.test(a) || /^192\.168\./.test(a) || /^169\.254\./.test(a)) return true;
  const m = /^172\.(\d+)\./.exec(a);
  if (m && Number(m[1]) >= 16 && Number(m[1]) <= 31) return true;
  return /^f[cd][0-9a-f]{2}:/i.test(a) || /^fe80:/i.test(a); // IPv6 local
}

const server = http.createServer(async (req, res) => {
  if (!isLocalAddress(req.socket.remoteAddress)) {
    res.writeHead(403);
    return res.end();
  }
  const u = new URL(req.url, 'http://localhost');
  const q = Object.fromEntries(u.searchParams);
  const parts = u.pathname.split('/').filter(Boolean);
  if (process.env.SLOP_DEBUG && !u.pathname.startsWith('/api/status')) log('REQ', req.method, u.pathname, req.headers.range || '');
  const abs = (p) => (/^https?:/.test(p) ? p : `http://${req.headers.host}${p}`);
  try {
    switch (u.pathname) {
      case '/api/ping': return sendJson(res, { ok: true, name: 'Slop+' });
      case '/api/home': {
        const cont = continueRow();
        return sendJson(res, { rows: [...(cont ? [cont] : []), ...(await getHome())] });
      }
      case '/api/continue': return sendJson(res, { row: continueRow() });
      case '/api/progress': saveProgress(q); return sendJson(res, { ok: true });
      case '/api/search': return sendJson(res, { rows: await search(s(q.q)) });
      case '/api/meta': return sendJson(res, await getMeta(s(q.type), s(q.id)));
      case '/api/streams': return sendJson(res, { streams: await getStreams(s(q.type), s(q.id)) });
      case '/api/play': {
        const r = await play(s(q.key), { audio: s(q.audio), start: Number(q.start) || 0, caps: parseCaps(q), force: s(q.force), vid: s(q.vid), resume: q.resume === '1' });
        return sendJson(res, { ...r, url: abs(r.url) });
      }
      case '/api/subs': return sendJson(res, { cues: await getCues(s(q.u), Number(q.off) || 0) });
      case '/api/stop': await stopSession(); return sendJson(res, { ok: true });
      case '/api/status': return sendJson(res, status());
      case '/api/reload': await loadAddons(); homeCache.rows = null; return sendJson(res, { ok: true });
      default: break;
    }
    if (parts[0] === 'stream' && session && session.id === parts[1] && session.file) return serveTorrentFile(req, res, session.file);
    if (parts[0] === 'hls') return serveHls(res, s(parts[1]), s(parts[2]));
    sendJson(res, { error: 'not found' }, 404);
  } catch (e) {
    if (e.message !== 'Cancelado') log('Erro em', u.pathname, '-', e.message);
    if (!res.headersSent) sendJson(res, { error: e.message }, 500);
  }
});

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  fs.rmSync(WORK_DIR, { recursive: true, force: true });
  fs.mkdirSync(WORK_DIR, { recursive: true });
  detectEncoder();
  loadHistory();
  await loadAddons();
  server.on('error', (e) => {
    log('Servidor:', e.message);
    process.exit(e.code === 'EADDRINUSE' ? 3 : 1);
  });
  server.listen(PORT, '0.0.0.0', () => {
    const ips = Object.values(os.networkInterfaces()).flat().filter((i) => i.family === 'IPv4' && !i.internal).map((i) => i.address);
    log(`Slop+ backend rodando: ${ips.map((ip) => `http://${ip}:${PORT}`).join('  ')}`);
  });
  process.on('SIGINT', async () => { await stopSession(); process.exit(0); });
  // Ao iniciar, a pasta de trabalho já foi apagada acima; o histórico fica em DATA_DIR
}
