// Testes do parser/ranking de streams e do parser de legendas. Rode: npm test
import test from 'node:test';
import assert from 'node:assert/strict';
import { parseStream, rankStreams, parseCues, isLocalAddress } from './server.js';

test('só aceita acessos da rede local', () => {
  for (const ok of ['127.0.0.1', '::1', '::ffff:192.168.1.20', '10.0.0.5', '172.16.0.1', '172.31.255.1', '169.254.3.3', 'fe80::1', 'fd12::1']) {
    assert.equal(isLocalAddress(ok), true, ok);
  }
  for (const bad of ['8.8.8.8', '::ffff:177.12.3.4', '172.32.0.1', '2804:14c::1', '', undefined]) {
    assert.equal(isLocalAddress(bad), false, String(bad));
  }
});

test('lê qualidade, peers, tamanho, fonte e idiomas do Torrentio', () => {
  const p = parseStream('Torrentio\n4k DV | HDR',
    'Матрица / The Matrix [1999 WEB-DL 2160p HDR10 Dolby Vision]\n👤 344 💾 18.45 GB ⚙️ Rutracker\n🇬🇧 / 🇷🇺', 'x.mkv');
  assert.equal(p.quality, '4K');
  assert.equal(p.res, 2160);
  assert.equal(p.peers, 344);
  assert.equal(p.size, '18.45 GB');
  assert.equal(p.source, 'Rutracker');
  assert.deepEqual(p.langs, ['EN', 'RU']);
  assert.ok(p.tags.includes('DV') && p.tags.includes('HDR'));
});

test('pack de série: arquivo da 2ª linha e Multi Audio', () => {
  const p = parseStream('Torrentio\n1080p',
    'Breaking.Bad.S01-S05.1080p.WEBRIP.HEVC\nBreaking.Bad.S01/Breaking.Bad.S01E01.1080p.mkv\n👤 28 💾 510.66 MB ⚙️ 1337x\nMulti Audio / 🇧🇷');
  assert.equal(p.quality, '1080p');
  assert.equal(p.file, 'Breaking.Bad.S01E01.1080p.mkv');
  assert.equal(p.size, '510.66 MB');
  assert.deepEqual(p.langs, ['Multi', 'PT-BR']);
  assert.ok(p.tags.includes('HEVC'));
});

test('CAM fica abaixo de SD', () => {
  assert.equal(parseStream('Torrentio\nCAM', 'Movie.2024.HDCAM.x264\n👤 900').quality, 'CAM');
  assert.equal(parseStream('Torrentio\nBDRip', 'Movie.BDRip.XviD\n👤 9').quality, 'SD');
});

test('ranking: qualidade primeiro, depois peers; 3D no fim do grupo', () => {
  const mk = (name, peers) => ({ ...parseStream(`Torrentio\n${name}`, `X\n👤 ${peers}`), id: `${name}-${peers}` });
  const out = rankStreams([mk('720p', 999), mk('1080p', 5), mk('4k', 1), mk('1080p 3D HSBS', 500), mk('1080p', 50), mk('CAM', 5000), mk('BDRip', 10)]);
  assert.deepEqual(out.map((x) => x.id), ['4k-1', '1080p-50', '1080p-5', '1080p 3D HSBS-500', '720p-999', 'BDRip-10', 'CAM-5000']);
});

test('legendas SRT com deslocamento e limpeza de tags', () => {
  const srt = '\uFEFF1\r\n00:00:02,000 --> 00:00:05,500\r\n<i>Olá</i> {\\an8}mundo\r\n\r\n2\r\n00:01:00,000 --> 00:01:02,000\r\nSegunda\r\n';
  assert.deepEqual(parseCues(srt), [[2, 5.5, 'Olá mundo'], [60, 62, 'Segunda']]);
  assert.deepEqual(parseCues(srt, 30), [[30, 32, 'Segunda']]);
});

test('legendas VTT', () => {
  const vtt = 'WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nOi\n\n01:00:00.500 --> 01:00:01.000\nTchau';
  assert.deepEqual(parseCues(vtt), [[1, 2, 'Oi'], [3600.5, 3601, 'Tchau']]);
});
