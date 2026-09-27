$ErrorActionPreference = 'Stop'
$script:Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

function Import-DotEnv {
  $envFile = Join-Path $script:Root '.env'
  if (-not (Test-Path -LiteralPath $envFile)) { return }
  foreach ($line in Get-Content -LiteralPath $envFile) {
    if ($line -match '^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$') {
      $value = $Matches[2].Trim()
      if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
        $value = $value.Substring(1, $value.Length - 2)
      }
      [Environment]::SetEnvironmentVariable($Matches[1], $value)
    }
  }
}

function Resolve-GrokBotApp {
  if ($env:GROKBOT_APP) { return (Resolve-Path -LiteralPath $env:GROKBOT_APP).Path }
  $candidates = @(
    (Join-Path $env:LOCALAPPDATA 'Programs\Grok Bot\Grok Bot.exe'),
    (Join-Path $env:LOCALAPPDATA 'Grok Bot\Grok Bot.exe'),
    (Join-Path $env:ProgramFiles 'Grok Bot\Grok Bot.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'Grok Bot\Grok Bot.exe')
  )
  foreach ($candidate in $candidates) { if ($candidate -and (Test-Path -LiteralPath $candidate)) { return $candidate } }
  throw 'Grok Bot.exe was not found. Set GROKBOT_APP to its full path.'
}

function Resolve-GrokBotResources([string]$appPath) {
  if ($env:GROKBOT_RESOURCES) { return (Resolve-Path -LiteralPath $env:GROKBOT_RESOURCES).Path }
  $resources = Join-Path (Split-Path -Parent $appPath) 'resources'
  if (Test-Path -LiteralPath $resources) { return $resources }
  throw "Grok Bot resources were not found at $resources. Set GROKBOT_RESOURCES."
}

function Test-HttpsHealth([string]$url = 'https://localhost:8443/health') {
  try {
    $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
    if ($curl) { & $curl.Source '-ks' '--max-time' '2' $url *> $null; return $LASTEXITCODE -eq 0 }
    Invoke-WebRequest -Uri $url -TimeoutSec 2 | Out-Null
    return $true
  } catch { return $false }
}

Import-DotEnv
