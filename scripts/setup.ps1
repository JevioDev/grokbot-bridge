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

foreach ($dir in @('certs', 'host/dist/host', 'host/dist/deps', 'appdata', 'logs', 'state/host-workdir')) { New-Item -ItemType Directory -Force -Path (Join-Path $script:Root $dir) | Out-Null }
$openssl = Get-Command openssl -ErrorAction SilentlyContinue
if (-not $openssl) { throw 'OpenSSL is required. Install it (for example through Git for Windows) and rerun setup.' }
$rootCa = Join-Path $script:Root 'certs/rootCA.pem'; $rootKey = Join-Path $script:Root 'certs/rootCA.key'
if (-not (Test-Path $rootCa) -or -not (Test-Path $rootKey)) {
  & $openssl.Source req -x509 -newkey rsa:2048 -nodes -sha256 -days 3650 -subj '/CN=grokbot-bridge local CA' -keyout $rootKey -out $rootCa 2>$null
  if ($LASTEXITCODE) { throw 'Could not generate the local CA certificate.' }
}
$localhostPem = Join-Path $script:Root 'certs/localhost.pem'; $localhostKey = Join-Path $script:Root 'certs/localhost.key'; $csr = Join-Path $script:Root 'certs/localhost.csr'
if (-not (Test-Path $localhostPem) -or -not (Test-Path $localhostKey)) {
  & $openssl.Source req -newkey rsa:2048 -nodes -sha256 -subj '/CN=localhost' -keyout $localhostKey -out $csr 2>$null
  $ext = Join-Path $script:Root 'certs/localhost.ext'; Set-Content -Path $ext -Value "subjectAltName=DNS:localhost,IP:127.0.0.1`nextendedKeyUsage=serverAuth"
  & $openssl.Source x509 -req -sha256 -days 825 -in $csr -CA $rootCa -CAkey $rootKey -CAcreateserial -extfile $ext -out $localhostPem 2>$null
  if ($LASTEXITCODE) { throw 'Could not generate the localhost certificate.' }
}

$asarCmd = Join-Path $nodeModules '.bin/asar.cmd'; $hostDir = Join-Path $script:Root 'host/dist/host'; $depsDir = Join-Path $script:Root 'host/dist/deps'
Push-Location $hostDir
try {
  & $asarCmd extract-file $asar 'dist/host/host-main.cjs'
  & $asarCmd extract-file $asar 'dist/host/host-main.cjs.map'
  if ($LASTEXITCODE) { throw 'Host runtime extraction failed.' }
} finally { Pop-Location }
Copy-Item -Recurse -Force (Join-Path $unpacked 'dist/deps/*') $depsDir
if (-not (Test-Path (Join-Path $hostDir 'host-main.cjs'))) { throw 'Host runtime extraction failed.' }
Write-Host "Setup complete. Next: .\run-all.ps1"
