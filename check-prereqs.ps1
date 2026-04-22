$flutter = Get-Command flutter -ErrorAction SilentlyContinue
$docker = Get-Command docker -ErrorAction SilentlyContinue
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$candidateFlutters = @(
  (Join-Path $scriptRoot "tools\flutter\bin\flutter.bat"),
  (Join-Path (Split-Path -Parent $scriptRoot) "tools\flutter\bin\flutter.bat")
) | Select-Object -Unique
$localFlutter = $candidateFlutters | Where-Object { Test-Path $_ } | Select-Object -First 1

Write-Host "Python local do workspace: OK"
Write-Host ("Flutter no PATH: " + ($(if ($flutter) { "OK" } else { "NAO ENCONTRADO" })))
Write-Host ("Flutter local do workspace: " + ($(if ($localFlutter) { "OK" } else { "NAO ENCONTRADO" })))
Write-Host ("Docker no PATH: " + ($(if ($docker) { "OK" } else { "NAO ENCONTRADO" })))

if ($localFlutter) {
  Write-Host "Flutter local encontrado em: $localFlutter"
}

if (-not $flutter -and -not $localFlutter) {
  Write-Host ""
  Write-Host "Para rodar o app mobile, instale o Flutter SDK e depois execute:"
  Write-Host "  powershell -ExecutionPolicy Bypass -File .\setup-mobile.ps1"
  Write-Host "  powershell -ExecutionPolicy Bypass -File .\run-tablet.ps1"
} elseif ($localFlutter) {
  Write-Host ""
  Write-Host "O Flutter local do workspace esta pronto para uso."
  Write-Host "Comandos sugeridos:"
  Write-Host "  powershell -ExecutionPolicy Bypass -File .\setup-mobile.ps1"
  Write-Host "  powershell -ExecutionPolicy Bypass -File .\run-tablet.ps1"
}
