. "$PSScriptRoot\scripts\windows-common.ps1"

$container = if ($env:GROKBOT_COMPUTER_CONTAINER) { $env:GROKBOT_COMPUTER_CONTAINER } else { 'grokbot-computer' }
$image = if ($env:GROKBOT_COMPUTER_IMAGE) { $env:GROKBOT_COMPUTER_IMAGE } else { 'public.ecr.aws/k0i0n2g5/cursorenvironments/universal@sha256:dcac90cba36653f261988b1c88d11b7655493d455c4af0a18c5991ddaa5da020' }

function Require-Docker {
  if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { throw 'Docker Desktop is required.' }
  & cmd.exe /d /c 'docker info >nul 2>nul'
  if ($LASTEXITCODE) { throw 'Docker Desktop daemon is not available.' }
}

# PowerShell 5.1 treats native stderr as an error record when ErrorActionPreference is Stop.
# Docker uses stderr for normal pull/progress output, so capture it explicitly and return only
# the native exit code to callers.
function Invoke-Docker {
  param(
    [Parameter(Mandatory = $true)] [string[]] $DockerArgs,
    [switch] $Quiet
  )

  $previousPreference = $ErrorActionPreference
  try {
    $ErrorActionPreference = 'Continue'
    $output = @(& docker @DockerArgs 2>&1)
    $exitCode = [int]$LASTEXITCODE
    if (-not $Quiet) {
      $output | ForEach-Object { Write-Host $_ }
    }
    return $exitCode
  } finally {
    $ErrorActionPreference = $previousPreference
  }
}

function Test-ComputerReady {
  return (Test-HttpHealth 'http://127.0.0.1:6080/vnc.html') -and (Test-HttpHealth 'http://127.0.0.1:1337/health')
}

function Test-ComputerContainer {
  return (Invoke-Docker -DockerArgs @('container', 'inspect', $container) -Quiet) -eq 0
}

function Start-Computer {
  Require-Docker

  if (Test-ComputerContainer) {
    $startCode = Invoke-Docker -DockerArgs @('start', $container) -Quiet
    if ($startCode -ne 0) { throw "Could not start Docker container '$container'." }
  } else {
    $pullCode = Invoke-Docker -DockerArgs @('pull', $image)
    if ($pullCode -ne 0) { throw "Could not pull Docker image '$image'." }

    $runCode = Invoke-Docker -DockerArgs @(
      'run', '-d', '--name', $container, '--restart', 'unless-stopped', '--shm-size=1g',
      '-p', '127.0.0.1:1337:1337',
      '-p', '127.0.0.1:1338:1338',
      '-p', '127.0.0.1:1339:1339',
      '-p', '127.0.0.1:1340:1340',
      '-p', '127.0.0.1:6080:6080',
      '-p', '127.0.0.1:6081:6081',
      '-v', 'grokbot-computer-workspace:/workspace',
      '-v', 'grokbot-computer-chrome:/home/box/chrome-profile',
      '-v', 'grokbot-computer-data:/home/box/sand-data',
      $image
    )
    if ($runCode -ne 0) { throw "Could not create Docker container '$container'." }
  }

  for ($i = 0; $i -lt 120; $i++) {
    if (Test-ComputerReady) {
      Write-Host 'computer ready: http://127.0.0.1:6080/vnc.html'
      return
    }
    Start-Sleep -Milliseconds 500
  }
  throw 'Computer did not become ready.'
}

Require-Docker
switch ($args[0]) {
  'start' {
    Start-Computer
  }
  'restart' {
    [void](Invoke-Docker -DockerArgs @('rm', '-f', $container) -Quiet)
    Start-Computer
  }
  'stop' {
    if (Test-ComputerContainer) {
      $stopCode = Invoke-Docker -DockerArgs @('stop', $container) -Quiet
      if ($stopCode -ne 0) { throw "Could not stop Docker container '$container'." }
      Write-Host "computer stopped: $container"
    } else {
      Write-Host "computer already stopped: $container"
    }
  }
  'logs' {
    $logsCode = Invoke-Docker -DockerArgs @('logs', '--tail', '200', $container)
    if ($logsCode -ne 0) { exit $logsCode }
  }
  'open' {
    Start-Process 'http://127.0.0.1:6080/vnc.html'
  }
  'status' {
    if (-not (Test-ComputerContainer)) {
      Write-Host "computer not created: $container"
      exit 1
    }
    if (Test-ComputerReady) {
      Write-Host "computer ready: $container"
    } else {
      Write-Host "computer not ready: $container"
      exit 1
    }
  }
  default {
    Write-Host 'usage: .\computerctl.ps1 {start|stop|restart|status|logs|open}'
    exit 2
  }
}
