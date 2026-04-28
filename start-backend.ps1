param(
  [switch]$Reload,
  [string]$Host = "0.0.0.0",
  [int]$Port = 8000
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$backendRoot = Join-Path $projectRoot "acolhe-backend"
$pythonExe = "C:\Users\USER\Documents\Playground\tools\python-3.11.9-embed-amd64\python.exe"

if (-not (Test-Path $pythonExe)) {
  throw "Python local nao encontrado em $pythonExe"
}

Set-Location $backendRoot

if (-not (Test-Path ".env")) {
  Copy-Item ".env.example" ".env"
}

if (-not $env:DATABASE_URL) {
  $env:DATABASE_URL = "sqlite:///./acolhe.db"
}

Write-Host "Usando Python local: $pythonExe"
Write-Host "Backend em: $backendRoot"
Write-Host "DATABASE_URL=$env:DATABASE_URL"
Write-Host "HOST=$Host"
Write-Host "PORT=$Port"

if ($Reload) {
  Write-Host "Iniciando com reload habilitado."
  & $pythonExe -m uvicorn app.main:app --host $Host --port $Port --reload
} else {
  Write-Host "Iniciando sem reload para evitar erros de watcher neste ambiente."
  & $pythonExe -m uvicorn app.main:app --host $Host --port $Port
}
