# Faz o backend do Slop+ iniciar sozinho (e escondido) quando você entra no Windows.
# Uso:  .\instalar-autostart.ps1            instala e já inicia
#       .\instalar-autostart.ps1 -Remover   desinstala
param([switch]$Remover)
$ErrorActionPreference = 'Stop'
$backend = Join-Path $PSScriptRoot 'backend'
$startup = [Environment]::GetFolderPath('Startup')
$vbs = Join-Path $startup 'Slop+ Backend.vbs'

function Stop-Backend {
  Get-CimInstance Win32_Process -Filter "Name='node.exe'" |
    Where-Object { $_.CommandLine -match 'supervisor\.js|server\.js' -and $_.CommandLine -notmatch '--test' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}

if ($Remover) {
  Remove-Item $vbs -ErrorAction SilentlyContinue
  Stop-Backend
  Write-Host 'Auto-start removido e backend parado.'
  return
}

$node = (Get-Command node).Source
$content = @"
' Inicia o backend do Slop+ sem janela
Set sh = CreateObject("WScript.Shell")
sh.CurrentDirectory = "$backend"
sh.Run """$node"" supervisor.js", 0, False
"@
[IO.File]::WriteAllText($vbs, $content, [Text.Encoding]::Unicode)

Stop-Backend
Start-Sleep 1
Start-Process wscript.exe -ArgumentList "`"$vbs`""
Write-Host "Auto-start instalado: $vbs"
Write-Host "Log: $env:LOCALAPPDATA\SlopPlus\backend.log"
