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
$normalizedApiBaseUrl = $ApiBaseUrl.Trim()

if ([string]::IsNullOrWhiteSpace($normalizedApiBaseUrl)) {
  throw "ApiBaseUrl no puede estar vacia."
}

if ($normalizedApiBaseUrl -match '^https?://(localhost|127\.0\.0\.1|10\.0\.2\.2)(:\d+)?(/|$)') {
  throw "ApiBaseUrl debe ser publica para una release de Play Console. No uses localhost ni 10.0.2.2."
}

if ($normalizedApiBaseUrl -notmatch '/api/?$') {
  $normalizedApiBaseUrl = $normalizedApiBaseUrl.TrimEnd('/') + '/api'
}

if (-not (Test-Path -LiteralPath $keyPropertiesPath)) {
  throw "Falta android/key.properties. Crea el archivo a partir de android/key.properties.example."
}

Push-Location $flutterAppPath
try {
  flutter pub get
  Write-Host "Usando API_BASE_URL=$normalizedApiBaseUrl"

  $args = @(
    "build", "appbundle", "--release",
    "--dart-define=API_BASE_URL=$normalizedApiBaseUrl"
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
