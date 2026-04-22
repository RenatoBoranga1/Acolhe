param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$FlutterArgs
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

function Resolve-FlutterRoot {
  param(
    [string]$BaseDir
  )

  $candidates = @(
    (Join-Path $BaseDir "tools\flutter"),
    (Join-Path (Split-Path -Parent $BaseDir) "tools\flutter")
  ) | Select-Object -Unique

  foreach ($candidate in $candidates) {
    if (Test-Path (Join-Path $candidate "bin\flutter.bat")) {
      return $candidate
    }
  }

  throw ("Flutter local nao encontrado. Caminhos verificados: " + ($candidates -join ", "))
}

$flutterRoot = Resolve-FlutterRoot -BaseDir $projectRoot
$flutterExe = Join-Path $flutterRoot "bin\flutter.bat"
$androidSdk = "C:\Users\USER\AppData\Local\Android\Sdk"
$androidStudioJbr = "C:\Program Files\Android\Android Studio\jbr"

$env:GIT_CONFIG_COUNT = "1"
$env:GIT_CONFIG_KEY_0 = "safe.directory"
$env:GIT_CONFIG_VALUE_0 = ($flutterRoot -replace '\\', '/')
$env:Path = (Join-Path $flutterRoot "bin") + ";" + $env:Path

if (Test-Path $androidSdk) {
  $env:ANDROID_SDK_ROOT = $androidSdk
  $env:ANDROID_HOME = $androidSdk
}

if (Test-Path $androidStudioJbr) {
  $env:JAVA_HOME = $androidStudioJbr
  $env:Path = (Join-Path $androidStudioJbr "bin") + ";" + $env:Path
}

Write-Host "Usando Flutter local: $flutterExe"
Write-Host "FLUTTER_ROOT=$flutterRoot"
if ($env:ANDROID_SDK_ROOT) {
  Write-Host "ANDROID_SDK_ROOT=$env:ANDROID_SDK_ROOT"
}
if ($env:JAVA_HOME) {
  Write-Host "JAVA_HOME=$env:JAVA_HOME"
}
& $flutterExe @FlutterArgs
