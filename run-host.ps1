. "$PSScriptRoot\scripts\windows-common.ps1"
$app = Resolve-GrokBotApp
$env:SAND_BACKEND_URL = if ($env:SAND_BACKEND_URL) { $env:SAND_BACKEND_URL } else { 'https://localhost:8443' }
$env:NODE_EXTRA_CA_CERTS = Join-Path $script:Root 'certs/rootCA.pem'
$env:SAND_HOST_PORT = if ($env:SAND_HOST_PORT) { $env:SAND_HOST_PORT } else { '8550' }
$env:SAND_GATEWAY_BIND_HOST = if ($env:SAND_GATEWAY_BIND_HOST) { $env:SAND_GATEWAY_BIND_HOST } else { '127.0.0.1' }
$env:SAND_GATEWAY_TOKEN = if ($env:SAND_GATEWAY_TOKEN) { $env:SAND_GATEWAY_TOKEN } else { 'shim-gateway-token' }
$env:SAND_DEV_INFERENCE_TOKEN_FILE = Join-Path $script:Root 'state/host-token.json'
$env:SAND_HOST_LOG_FILE = if ($env:SAND_HOST_LOG_FILE) { $env:SAND_HOST_LOG_FILE } else { Join-Path $script:Root 'logs/host.log' }
$env:ELECTRON_RUN_AS_NODE = '1'
New-Item -ItemType Directory -Force -Path (Join-Path $script:Root 'state/host-workdir') | Out-Null
if (-not (Test-Path (Join-Path $script:Root 'host/dist/host/host-main.cjs'))) { throw 'Host runtime is missing; run: npm run setup' }
if (-not (Test-HttpsHealth "$($env:SAND_BACKEND_URL)/health")) { throw "Backend shim is not running on $env:SAND_BACKEND_URL" }
Push-Location (Join-Path $script:Root 'state/host-workdir'); try { & $app (Join-Path $script:Root 'host/dist/host/host-main.cjs') @args; exit $LASTEXITCODE } finally { Pop-Location }
