# Empacota o canal Slop+ e instala no Roku (modo desenvolvedor).
# Usa os dados salvos pelo instalar.ps1 em "configuracao-local.json" (que NUNCA vai para o git).
# Também aceita parâmetros: .\deploy.ps1 -RokuIp 192.168.x.x -Senha suaSenhaDev [-PcIp 192.168.x.x]
param(
  [string]$RokuIp,
  [string]$Senha,
  [string]$PcIp,
  [switch]$SoEmpacotar  # só gera o slop-plus.zip, sem enviar ao Roku
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$src = Join-Path $root 'roku'
$localFile = Join-Path $root 'configuracao-local.json'

if (Test-Path $localFile) {
  $local = Get-Content $localFile -Raw | ConvertFrom-Json
  if (-not $RokuIp) { $RokuIp = $local.rokuIp }
  if (-not $Senha) { $Senha = $local.rokuSenha }
  if (-not $PcIp) { $PcIp = $local.pcIp }
}
if (-not $SoEmpacotar -and (-not $RokuIp -or -not $Senha)) { throw 'Faltam o IP e a senha do Roku. Rode primeiro o instalar.ps1.' }
if (-not $PcIp) {
  $PcIp = (Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' -and $_.PrefixOrigin -ne 'WellKnown' } |
    Select-Object -First 1).IPAddress
}

# O IP do PC entra só no pacote enviado ao Roku; o arquivo Config.brs do projeto não é alterado
$cfg = "function BackendUrl() as string`n    return `"http://$($PcIp):8787`"`nend function`n"

# Zip com barras "/" (o Compress-Archive do PowerShell 5 usa "\" e o Roku rejeita)
$zipPath = Join-Path $root 'slop-plus.zip'
if (Test-Path $zipPath) { Remove-Item $zipPath }
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::Open($zipPath, 'Create')
Get-ChildItem $src -Recurse -File | ForEach-Object {
  $rel = $_.FullName.Substring($src.Length + 1).Replace('\', '/')
  if ($rel -eq 'components/Config.brs') {
    $w = New-Object IO.StreamWriter ($zip.CreateEntry($rel).Open())
    $w.Write($cfg); $w.Dispose()
  } else {
    [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $_.FullName, $rel) | Out-Null
  }
}
$zip.Dispose()
if ($SoEmpacotar) { Write-Host "Pacote gerado: $zipPath (backend http://$($PcIp):8787)"; return }

$out = curl.exe -s -S --digest -u "rokudev:$Senha" -F "mysubmit=Install" -F "archive=@$zipPath" "http://$RokuIp/plugin_install"
Remove-Item $zipPath -ErrorAction SilentlyContinue
if ($out -match 'Install Success|Identical to previous') {
  Write-Host "OK: Slop+ instalado no Roku $RokuIp (backend http://$($PcIp):8787)" -ForegroundColor Green
} else {
  ($out -replace '<[^>]+>', '') | Where-Object { $_.Trim() } | Select-Object -Last 15
  throw 'Falha no deploy. Confira: IP e senha do Roku corretos? Modo desenvolvedor ativo? Roku e PC na mesma rede?'
}
