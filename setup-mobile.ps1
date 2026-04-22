$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$mobileRoot = Join-Path $projectRoot "acolhe-mobile"
$flutterWrapper = Join-Path $projectRoot "flutter-local.ps1"

function Invoke-CheckedPowerShell {
  param(
    [string]$Description,
    [string[]]$Arguments
  )

  & powershell @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "$Description falhou com codigo $LASTEXITCODE."
  }
}

if (-not (Test-Path $mobileRoot)) {
  throw "Pasta mobile nao encontrada em $mobileRoot"
}

Set-Location $mobileRoot

Write-Host "Preparando app Flutter em: $mobileRoot"
Write-Host "Gerando plataformas nativas..."
Invoke-CheckedPowerShell -Description "Geracao das plataformas nativas" -Arguments @(
  "-ExecutionPolicy",
  "Bypass",
  "-File",
  $flutterWrapper,
  "create",
  "."
)

Write-Host "Baixando dependencias..."
Invoke-CheckedPowerShell -Description "Download das dependencias do Flutter" -Arguments @(
  "-ExecutionPolicy",
  "Bypass",
  "-File",
  $flutterWrapper,
  "pub",
  "get"
)

if (-not (Test-Path (Join-Path $mobileRoot "android"))) {
  throw "A pasta android nao foi gerada. Verifique a instalacao local do Flutter."
}

Write-Host ""
Write-Host "Setup mobile concluido."
Write-Host "Para listar aparelhos:"
Write-Host "  powershell -ExecutionPolicy Bypass -File .\flutter-local.ps1 devices"
Write-Host "Para rodar no tablet:"
Write-Host "  powershell -ExecutionPolicy Bypass -File .\run-tablet.ps1 -DeviceId SEU_DEVICE_ID"
Write-Host ""
Write-Host "Para usar o botao Run no Android Studio:"
Write-Host "  1. Abra a pasta .\acolhe-mobile"
Write-Host "  2. Configure o Flutter SDK em C:\Users\USER\Documents\Playground\tools\flutter"
Write-Host "  3. Aguarde o Gradle sync"
Write-Host "  4. Selecione o emulador ou tablet"
Write-Host "  5. Clique em Run"
