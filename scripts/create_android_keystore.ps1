param(
  [string]$KeystorePath = "$env:USERPROFILE\upload-keystore.jks",
  [string]$Alias = "upload",
  [int]$ValidityDays = 10000,
  [string]$KeytoolPath = "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe",
  [switch]$Force
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $KeytoolPath)) {
  throw "No se encuentra keytool en '$KeytoolPath'. Verifica la instalación de Android Studio."
}

if ((Test-Path -LiteralPath $KeystorePath) -and -not $Force) {
  throw "El keystore ya existe en '$KeystorePath'. Usa -Force para sobrescribirlo."
}

if ($Force -and (Test-Path -LiteralPath $KeystorePath)) {
  Remove-Item -LiteralPath $KeystorePath -Force
}

Write-Host "Generando keystore de subida en '$KeystorePath'..."
& $KeytoolPath `
  -genkeypair `
  -v `
  -keystore $KeystorePath `
  -storetype JKS `
  -keyalg RSA `
  -keysize 2048 `
  -validity $ValidityDays `
  -alias $Alias

$repoRoot = Split-Path -Parent $PSScriptRoot
$androidPath = Join-Path $repoRoot "flutter_app\android"
$templatePath = Join-Path $androidPath "key.properties.example"
$targetPath = Join-Path $androidPath "key.properties"

if (-not (Test-Path -LiteralPath $targetPath)) {
  if (-not (Test-Path -LiteralPath $templatePath)) {
    throw "No existe la plantilla '$templatePath'."
  }

  Copy-Item -LiteralPath $templatePath -Destination $targetPath
  $normalizedPath = $KeystorePath.Replace("\", "/")
  $lines = Get-Content -LiteralPath $targetPath
  $updated = $lines | ForEach-Object {
    if ($_ -match "^storeFile=") {
      "storeFile=$normalizedPath"
    } else {
      $_
    }
  }
  Set-Content -LiteralPath $targetPath -Value $updated -Encoding UTF8
}

Write-Host ""
Write-Host "Keystore creado correctamente."
Write-Host "Archivo generado: $KeystorePath"
Write-Host "Revisa y completa las contraseñas en: $targetPath"
