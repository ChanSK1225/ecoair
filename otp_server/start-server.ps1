param([switch]$Restart)

$ErrorActionPreference = 'Stop'
$serverRoot = $PSScriptRoot
$port = 3001
$health = $null
try {
    $health = Invoke-RestMethod -Uri "http://127.0.0.1:$port/health" -TimeoutSec 2
} catch {
    # Start the service when it is not already available.
}
if ($health.ok -and $null -ne $health.resendConfigured) {
    if (!$Restart) {
        Write-Output 'EcoAir backend is already running. Use -Restart after editing .env.'
        return
    }
    $listener = Get-NetTCPConnection -LocalPort $port -State Listen | Select-Object -First 1
    $existingProcess = Get-CimInstance Win32_Process -Filter "ProcessId = $($listener.OwningProcess)"
    if ($existingProcess.Name -ne 'node.exe' -or $existingProcess.CommandLine -notmatch 'server\.js') {
        throw 'Port 3001 belongs to another process. It was not stopped.'
    }
    Stop-Process -Id $listener.OwningProcess
}
$node = (Get-Command node -ErrorAction Stop).Source
$logRoot = Join-Path $serverRoot '.logs'
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
$process = Start-Process -FilePath $node -ArgumentList 'server.js' -WorkingDirectory $serverRoot -WindowStyle Hidden -RedirectStandardOutput (Join-Path $logRoot 'server.log') -RedirectStandardError (Join-Path $logRoot 'server-error.log') -PassThru
for ($attempt = 0; $attempt -lt 20; $attempt++) {
    Start-Sleep -Milliseconds 250
    if ($process.HasExited) { throw 'Backend stopped. Check otp_server/.logs/server-error.log.' }
    try {
        $health = Invoke-RestMethod -Uri "http://127.0.0.1:$port/health" -TimeoutSec 2
        if ($health.ok) {
            Write-Output "EcoAir backend is running on port $port (PID $($process.Id))."
            return
        }
    } catch { }
}
throw 'Backend did not become ready. Check otp_server/.logs/server-error.log.'
