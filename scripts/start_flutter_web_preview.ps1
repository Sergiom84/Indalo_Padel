param(
  [int]$Port = 59798
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$flutterApp = Join-Path $repoRoot 'flutter_app'
$buildWeb = Join-Path $flutterApp 'build\web'

Set-Location $flutterApp

Write-Host 'Compilando Flutter Web en modo debug sin sourcemaps...'
flutter build web --debug --no-source-maps

Set-Location $buildWeb

Write-Host "Sirviendo preview web en http://localhost:$Port"
python -m http.server $Port
