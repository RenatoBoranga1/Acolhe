param(
  [string]$DeviceId,
  [string]$ApiBaseUrl = "",
  [string[]]$ExtraArgs = @()
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$mobileRoot = Join-Path $projectRoot "acolhe-mobile"
$flutterWrapper = Join-Path $projectRoot "flutter-local.ps1"

if (-not (Test-Path $flutterWrapper)) {
  throw "Wrapper Flutter nao encontrado em $flutterWrapper"
}

if (-not (Test-Path $mobileRoot)) {
  throw "Pasta mobile nao encontrada em $mobileRoot"
}

Set-Location $mobileRoot

if (-not (Test-Path (Join-Path $mobileRoot "android"))) {
  Write-Host "Pastas nativas nao encontradas. Executando setup mobile primeiro..."
  & powershell -ExecutionPolicy Bypass -File (Join-Path $projectRoot "setup-mobile.ps1")
  if ($LASTEXITCODE -ne 0) {
    throw "Setup mobile falhou com codigo $LASTEXITCODE."
  }
}

if ([string]::IsNullOrWhiteSpace($DeviceId)) {
  Write-Host "Nenhum DeviceId foi informado."
  Write-Host "Aparelhos disponiveis:"
  & powershell -ExecutionPolicy Bypass -File $flutterWrapper devices
  Write-Host ""
  Write-Host "Exemplo de uso:"
  Write-Host "  powershell -ExecutionPolicy Bypass -File .\run-tablet.ps1 -DeviceId R9YT12345"
  Write-Host "Com backend remoto:"
  Write-Host "  powershell -ExecutionPolicy Bypass -File .\run-tablet.ps1 -DeviceId R9YT12345 -ApiBaseUrl http://192.168.0.15:8000"
  Write-Host "Com metadados de debug do chat:"
  Write-Host "  powershell -ExecutionPolicy Bypass -File .\run-tablet.ps1 -DeviceId R9YT12345 -ExtraArgs ""--dart-define=ACOLHE_DEBUG_CHAT=true"""
  exit 1
}

$runArgs = @("run", "-d", $DeviceId)

if (-not [string]::IsNullOrWhiteSpace($ApiBaseUrl)) {
  $runArgs += "--dart-define=API_BASE_URL=$ApiBaseUrl"
}

if ($ExtraArgs.Count -gt 0) {
  $runArgs += $ExtraArgs
}

Write-Host "Rodando app no dispositivo $DeviceId"
if (-not [string]::IsNullOrWhiteSpace($ApiBaseUrl)) {
  Write-Host "API_BASE_URL=$ApiBaseUrl"
} else {
  Write-Host "Usando mocks locais (sem API_BASE_URL)."
}

& powershell -ExecutionPolicy Bypass -File $flutterWrapper @runArgs
if ($LASTEXITCODE -ne 0) {
  throw "Execucao do Flutter falhou com codigo $LASTEXITCODE."
}
