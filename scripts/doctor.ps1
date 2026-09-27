. "$PSScriptRoot\windows-common.ps1"
$failed = $false
function Check-Command($name) { if (Get-Command $name -ErrorAction SilentlyContinue) { Write-Host "ok  $name" } else { Write-Host "missing  $name"; $script:failed = $true } }
function Check-File($path) { if (Test-Path -LiteralPath $path) { Write-Host "ok  $path" } else { Write-Host "missing  $path"; $script:failed = $true } }
Check-Command node; Check-Command npm; Check-Command openssl; Check-Command docker
try { $app = Resolve-GrokBotApp; Check-File $app } catch { Write-Host "missing  Grok Bot.exe"; $failed = $true }
Check-File (Join-Path $script:Root 'certs/rootCA.pem'); Check-File (Join-Path $script:Root 'certs/localhost.pem'); Check-File (Join-Path $script:Root 'certs/localhost.key'); Check-File (Join-Path $script:Root 'host/dist/host/host-main.cjs')
if (Get-Command docker -ErrorAction SilentlyContinue) { & cmd.exe /d /c 'docker info >nul 2>nul'; if ($LASTEXITCODE) { Write-Host 'unavailable  Docker daemon'; $failed = $true } else { Write-Host 'ok  Docker daemon' } }
if ($failed) { throw 'Doctor found missing prerequisites; run: npm run setup' }
Write-Host 'ready'
