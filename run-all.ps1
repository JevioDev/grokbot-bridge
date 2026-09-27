. "$PSScriptRoot\scripts\windows-common.ps1"

$computerCtl = Join-Path $script:Root 'computerctl.ps1'
$shimCtl = Join-Path $script:Root 'shimctl.ps1'
$runtimeMode = Get-BridgeRuntimeMode
$computerWasRunning = $false
& $computerCtl status *> $null
if ($LASTEXITCODE -eq 0) { $computerWasRunning = $true }
$shimWasRunning = Test-HttpsHealth
$hostWasRunning = Test-TcpPort '127.0.0.1' 8550
$hostProc = $null

try {
  & $computerCtl start
  if (-not $shimWasRunning) { & $shimCtl start }

  if ($runtimeMode -eq 'modern') {
    $gatewayReady = $false
    for ($i = 0; $i -lt 40; $i++) {
      if (Test-TcpPort '127.0.0.1' 1340) { $gatewayReady = $true; break }
      Start-Sleep -Milliseconds 250
    }
    if (-not $gatewayReady) { throw 'Computer host gateway did not start on 127.0.0.1:1340.' }
    & (Join-Path $script:Root 'run-recon.ps1') @args
    return
  }

  $hostOut = Join-Path $script:Root 'logs/host.out'
  $hostErr = Join-Path $script:Root 'logs/host.err'
  if (-not $hostWasRunning) {
    $hostProc = Start-Process powershell -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $script:Root 'run-host.ps1') -WorkingDirectory $script:Root -RedirectStandardOutput $hostOut -RedirectStandardError $hostErr -PassThru
    $ready = $false
    for ($i = 0; $i -lt 40; $i++) {
      if (Test-TcpPort '127.0.0.1' 8550) { $ready = $true; break }
      if ($hostProc.HasExited) { break }
      Start-Sleep -Milliseconds 250
    }
    if (-not $ready) { throw "Host gateway did not start on 127.0.0.1:8550; inspect $hostOut and $hostErr" }
  } else {
    Write-Host 'host gateway already running on http://127.0.0.1:8550'
  }

  & (Join-Path $script:Root 'run-recon.ps1') @args
} finally {
  if ($hostProc) { & taskkill.exe /PID $hostProc.Id /T /F *> $null }
  if (-not $shimWasRunning) { & $shimCtl stop *> $null }
  if (-not $computerWasRunning) { & $computerCtl stop *> $null }
}
