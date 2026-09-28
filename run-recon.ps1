. "$PSScriptRoot\scripts\windows-common.ps1"
$app = Resolve-GrokBotApp
$runtimeMode = Get-BridgeRuntimeMode
$env:SAND_BACKEND_URL = if ($env:SAND_BACKEND_URL) { $env:SAND_BACKEND_URL } else { 'https://localhost:8443' }
$env:NODE_EXTRA_CA_CERTS = Join-Path $script:Root 'certs/rootCA.pem'
$env:SAND_DEV_LOGIN = if ($env:SAND_DEV_LOGIN) { $env:SAND_DEV_LOGIN } else { 'Ultra' }
$env:SAND_DEV_LOGIN_EMAIL = if ($env:SAND_DEV_LOGIN_EMAIL) { $env:SAND_DEV_LOGIN_EMAIL } else { 'shim@local' }
$env:SAND_HOST_GATEWAY_URL = if ($env:SAND_HOST_GATEWAY_URL) { $env:SAND_HOST_GATEWAY_URL } elseif ($runtimeMode -eq 'modern') { 'http://127.0.0.1:1340' } else { 'http://localhost:8550' }
$env:SAND_HOST_GATEWAY_TOKEN = if ($env:SAND_HOST_GATEWAY_TOKEN) { $env:SAND_HOST_GATEWAY_TOKEN } else { 'shim-gateway-token' }
New-Item -ItemType Directory -Force -Path (Join-Path $script:Root 'appdata'), (Join-Path $script:Root 'logs') | Out-Null
if (-not (Test-HttpsHealth "$($env:SAND_BACKEND_URL)/health")) { & (Join-Path $script:Root 'shimctl.ps1') start }
if ($runtimeMode -eq 'modern' -and -not (Test-HttpHealth 'http://127.0.0.1:1340/health')) { throw 'Modern Grok Bot runtime requires Computer host gateway on 127.0.0.1:1340.' }
& $app '--no-sandbox' "--user-data-dir=$(Join-Path $script:Root 'appdata')" @args
exit $LASTEXITCODE
