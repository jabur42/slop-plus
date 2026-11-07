# Instalador do Slop+ (Windows). Rode no PowerShell, dentro da pasta do projeto:
#   powershell -ExecutionPolicy Bypass -File .\instalar.ps1
# Faz tudo: instala as dependências, pergunta o IP e a senha do seu Roku, liga o backend
# junto com o Windows e instala o canal no Roku.
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$localFile = Join-Path $root 'configuracao-local.json'

function Passo($n, $t) { Write-Host "`n[$n/5] $t" -ForegroundColor Cyan }

Passo 1 'Conferindo o Node.js'
$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) {
  Write-Host 'Node.js não encontrado. Instale a versão LTS em https://nodejs.org e rode este instalador de novo.' -ForegroundColor Yellow
  exit 1
}
$major = [int]((node -v).TrimStart('v').Split('.')[0])
if ($major -lt 20) { Write-Host "Node.js $(node -v) é antigo. Instale a versão 20 ou mais nova." -ForegroundColor Yellow; exit 1 }
Write-Host "Node.js $(node -v) OK"

Passo 2 'Instalando as dependências do backend (pode levar alguns minutos)'
Push-Location (Join-Path $root 'backend')
npm install --no-fund --no-audit
if ($LASTEXITCODE -ne 0) { Pop-Location; throw 'npm install falhou' }
if (-not (Test-Path 'config.json')) { Copy-Item 'config.example.json' 'config.json' }
Pop-Location

Passo 3 'Dados do seu Roku'
Write-Host 'Esses dados ficam SOMENTE neste PC, no arquivo configuracao-local.json (ignorado pelo git).'
Write-Host 'Para achar o IP do Roku: Configurações > Rede > Sobre.'
$old = $null
if (Test-Path $localFile) { $old = Get-Content $localFile -Raw | ConvertFrom-Json }
$rokuIp = Read-Host "IP do Roku$(if ($old) { " [$($old.rokuIp)]" })"
if (-not $rokuIp -and $old) { $rokuIp = $old.rokuIp }
$sec = Read-Host 'Senha do modo desenvolvedor do Roku (a que você criou ao ativá-lo)' -AsSecureString
$senha = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
if (-not $senha -and $old) { $senha = $old.rokuSenha }

$ips = @(Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } | Select-Object -ExpandProperty IPAddress)
# Prefere o IP da mesma rede do Roku
$prefix = ($rokuIp -split '\.')[0..2] -join '.'
$pcIp = ($ips | Where-Object { $_ -like "$prefix.*" } | Select-Object -First 1)
if (-not $pcIp) { $pcIp = $ips | Select-Object -First 1 }
Write-Host "IP deste PC na rede: $pcIp"

try { Invoke-WebRequest "http://$($rokuIp):8060/query/device-info" -UseBasicParsing -TimeoutSec 5 | Out-Null; Write-Host 'Roku encontrado na rede.' -ForegroundColor Green }
catch { Write-Host "Não consegui falar com o Roku em $rokuIp. Confira o IP e se ele está ligado." -ForegroundColor Yellow }

@{ rokuIp = $rokuIp; rokuSenha = $senha; pcIp = $pcIp } | ConvertTo-Json | Set-Content $localFile -Encoding ascii

Passo 4 'Ligando o backend (inicia sozinho junto com o Windows)'
& (Join-Path $root 'instalar-autostart.ps1')
Start-Sleep 8
try { Invoke-RestMethod 'http://127.0.0.1:8787/api/ping' -TimeoutSec 10 | Out-Null; Write-Host 'Backend rodando.' -ForegroundColor Green }
catch { Write-Host "O backend não respondeu ainda. Veja o log em $env:LOCALAPPDATA\SlopPlus\backend.log" -ForegroundColor Yellow }
Write-Host 'Se o Windows perguntar sobre o Firewall para o Node.js, clique em PERMITIR (rede privada).' -ForegroundColor Yellow

Passo 5 'Instalando o canal no Roku'
& (Join-Path $root 'deploy.ps1')
Write-Host "`nPronto! Abra o canal Slop+ no seu Roku." -ForegroundColor Green
