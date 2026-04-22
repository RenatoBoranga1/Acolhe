$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$backendRoot = Join-Path $projectRoot "acolhe-backend"
$pythonExe = "C:\Users\USER\Documents\Playground\tools\python-3.11.9-embed-amd64\python.exe"

if (-not (Test-Path $pythonExe)) {
  throw "Python local nao encontrado em $pythonExe"
}

Set-Location $backendRoot

Write-Host "Executando testes do backend com Python local..."
& $pythonExe -m pytest -q
