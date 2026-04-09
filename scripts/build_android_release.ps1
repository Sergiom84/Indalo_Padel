param(
  [Parameter(Mandatory = $true)]
  [string]$ApiBaseUrl,
  [string]$BuildName = "",
  [string]$BuildNumber = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$flutterAppPath = Join-Path $repoRoot "flutter_app"
$keyPropertiesPath = Join-Path $flutterAppPath "android\\key.properties"

if (-not (Test-Path -LiteralPath $keyPropertiesPath)) {
  throw "Falta android/key.properties. Crea el archivo a partir de android/key.properties.example."
}

Push-Location $flutterAppPath
try {
  flutter pub get

  $args = @(
    "build", "appbundle", "--release",
    "--dart-define=API_BASE_URL=$ApiBaseUrl"
  )

  if ($BuildName -ne "") {
    $args += "--build-name=$BuildName"
  }

  if ($BuildNumber -ne "") {
    $args += "--build-number=$BuildNumber"
  }

  & flutter @args
} finally {
  Pop-Location
}
