. "$PSScriptRoot\windows-common.ps1"

$app = Resolve-GrokBotApp
$resources = Resolve-GrokBotResources $app
$asar = Join-Path $resources 'app.asar'
$unpacked = Join-Path $resources 'app.asar.unpacked'
if (-not (Test-Path -LiteralPath $asar) -or -not (Test-Path -LiteralPath (Join-Path $unpacked 'dist/deps'))) {
  throw "Grok Bot resources were not found at $resources"
}

$nodeModules = Join-Path $script:Root 'node_modules'
if (-not (Test-Path -LiteralPath (Join-Path $nodeModules '.bin/asar.cmd'))) {
  Write-Host 'Installing Node.js dependencies...'
  npm --prefix $script:Root ci
}
$asarCmd = Join-Path $nodeModules '.bin/asar.cmd'
$archiveEntries = @(& $asarCmd list $asar)
$hasLegacyRuntime = [bool]($archiveEntries | Where-Object { $_ -match '\\dist\\host\\host-main\.cjs$' })
$hasModernRuntime = [bool]($archiveEntries | Where-Object { $_ -match '\\dist\\node-agent-coordinator\\main\.cjs$' })
if (-not $hasLegacyRuntime -and -not $hasModernRuntime) {
  throw "This Grok Bot build is not compatible: $asar contains neither the legacy host runtime nor the modern node-agent-coordinator."
}
$runtimeMode = if ($hasLegacyRuntime) { 'legacy' } else { 'modern' }

foreach ($dir in @('certs', 'host/dist/host', 'host/dist/deps', 'appdata', 'logs', 'state/host-workdir')) { New-Item -ItemType Directory -Force -Path (Join-Path $script:Root $dir) | Out-Null }
Set-Content -Path (Join-Path $script:Root 'state/runtime-mode.json') -Value (@{ mode = $runtimeMode } | ConvertTo-Json)
$openssl = Resolve-OpenSsl
$opensslRoot = Split-Path (Split-Path $openssl -Parent) -Parent
$opensslConfig = @(
  (Join-Path $opensslRoot 'ssl/openssl.cnf'),
  (Join-Path (Split-Path $openssl -Parent) '../ssl/openssl.cnf')
) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
function Invoke-OpenSsl([string[]]$Arguments) {
  $previousPreference = $ErrorActionPreference
  try {
    # OpenSSL writes key-generation progress to stderr even on success. Windows
    # PowerShell otherwise promotes that normal progress output to an error.
    $ErrorActionPreference = 'Continue'
    & $openssl @Arguments 2>$null
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousPreference
  }
  return $exitCode
}
$rootCa = Join-Path $script:Root 'certs/rootCA.pem'; $rootKey = Join-Path $script:Root 'certs/rootCA.key'
if (-not (Test-Path $rootCa) -or -not (Test-Path $rootKey)) {
  $rootArgs = @('req')
  if ($opensslConfig) { $rootArgs += @('-config', $opensslConfig) }
  $rootArgs += @('-x509', '-newkey', 'rsa:2048', '-nodes', '-sha256', '-days', '3650', '-subj', '/CN=grokbot-bridge local CA', '-keyout', $rootKey, '-out', $rootCa)
  if ((Invoke-OpenSsl $rootArgs) -ne 0) { throw 'Could not generate the local CA certificate.' }
}
$localhostPem = Join-Path $script:Root 'certs/localhost.pem'; $localhostKey = Join-Path $script:Root 'certs/localhost.key'; $csr = Join-Path $script:Root 'certs/localhost.csr'
if (-not (Test-Path $localhostPem) -or -not (Test-Path $localhostKey)) {
  $requestArgs = @('req')
  if ($opensslConfig) { $requestArgs += @('-config', $opensslConfig) }
  $requestArgs += @('-newkey', 'rsa:2048', '-nodes', '-sha256', '-subj', '/CN=localhost', '-keyout', $localhostKey, '-out', $csr)
  if ((Invoke-OpenSsl $requestArgs) -ne 0) { throw 'Could not generate the localhost certificate key.' }
  $ext = Join-Path $script:Root 'certs/localhost.ext'; Set-Content -Path $ext -Value "subjectAltName=DNS:localhost,IP:127.0.0.1`nextendedKeyUsage=serverAuth"
  $certificateArgs = @('x509', '-req', '-sha256', '-days', '825', '-in', $csr, '-CA', $rootCa, '-CAkey', $rootKey, '-CAcreateserial', '-extfile', $ext, '-out', $localhostPem)
  if ((Invoke-OpenSsl $certificateArgs) -ne 0) { throw 'Could not generate the localhost certificate.' }
}

$hostDir = Join-Path $script:Root 'host/dist/host'; $depsDir = Join-Path $script:Root 'host/dist/deps'
if ($runtimeMode -eq 'legacy') {
  Push-Location $hostDir
  try {
    & $asarCmd extract-file $asar 'dist\host\host-main.cjs'
    & $asarCmd extract-file $asar 'dist\host\host-main.cjs.map'
    if ($LASTEXITCODE) { throw 'Host runtime extraction failed.' }
  } finally { Pop-Location }
}
Copy-Item -Recurse -Force (Join-Path $unpacked 'dist/deps/*') $depsDir
if ($runtimeMode -eq 'legacy' -and -not (Test-Path (Join-Path $hostDir 'host-main.cjs'))) { throw 'Host runtime extraction failed.' }
Write-Host "Setup complete (runtime: $runtimeMode). Next: .\run-all.ps1"
