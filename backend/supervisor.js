// Mantém o backend do Slop+ rodando: reinicia se cair e grava log.
// Iniciado automaticamente com o Windows (veja instalar-autostart.ps1).
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const dir = path.dirname(fileURLToPath(import.meta.url));
const logDir = path.join(process.env.LOCALAPPDATA || dir, 'SlopPlus');
fs.mkdirSync(logDir, { recursive: true });
const logFile = path.join(logDir, 'backend.log');

function rotate() {
  try { if (fs.statSync(logFile).size > 5e6) fs.renameSync(logFile, logFile + '.old'); } catch { /* sem log ainda */ }
}

function start() {
  rotate();
  const out = fs.openSync(logFile, 'a');
  const child = spawn(process.execPath, ['server.js'], { cwd: dir, stdio: ['ignore', out, out], windowsHide: true });
  const t0 = Date.now();
  child.on('exit', (code) => {
    fs.closeSync(out);
    // 3 = porta ocupada (outro backend já está rodando): espera mais antes de tentar de novo
    const wait = code === 3 ? 30000 : Date.now() - t0 < 10000 ? 10000 : 2000;
    fs.appendFileSync(logFile, `${new Date().toLocaleString()} backend saiu (código ${code}), reiniciando em ${wait / 1000}s\n`);
    setTimeout(start, wait);
  });
}
start();
