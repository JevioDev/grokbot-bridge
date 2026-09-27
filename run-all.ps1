. "$PSScriptRoot\scripts\windows-common.ps1"
& (Join-Path $script:Root 'computerctl.ps1') start
& (Join-Path $script:Root 'shimctl.ps1') restart
$hostOut = Join-Path $script:Root 'logs/host.out'; $hostErr = Join-Path $script:Root 'logs/host.err'
$hostProc = Start-Process powershell -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $script:Root 'run-host.ps1') -WorkingDirectory $script:Root -RedirectStandardOutput $hostOut -RedirectStandardError $hostErr -PassThru
try { & (Join-Path $script:Root 'run-recon.ps1') @args } finally { Stop-Process -Id $hostProc.Id -Force -ErrorAction SilentlyContinue }
