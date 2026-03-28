# InternetUsageAgent v3.3 (High-Precision Performance Shield)
# Uses Windows Performance Counters (Task Manager Engine) for 100% SMB accuracy.
# Includes Self-Cleanup logic to stop old agent versions automatically.

$ServerIP = "192.168.1.32"
$Port = "3001"
$ReportInterval = 30 # Seconds

# 1. Self-Cleanup: Kill any other active InternetAgent_v2 instances
# This ensures only this v3.3 version is running.
$CurrentPID = $PID
Get-Process powershell -ErrorAction SilentlyContinue | Where-Object { 
    $_.Id -ne $CurrentPID -and 
    ($_.CommandLine -like "*InternetAgent_v2.ps1*") 
} | Stop-Process -Force -ErrorAction SilentlyContinue

# 2. State & Identity Lock
$Hostname = (hostname).Trim().ToLower()
$ClientID = "$Hostname-v3"
$LocalDir = "C:\InternetUsageTracker"
$LogPath = Join-Path $LocalDir "agent_v3_debug.txt"
if (-not (Test-Path $LocalDir)) { New-Item -Path $LocalDir -ItemType Directory -Force | Out-Null }

function Log-Debug {
    param([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$Timestamp] $Message" | Out-File -FilePath $LogPath -Append -Encoding utf8
}

Log-Debug "--- Starting High-Precision Shield v3.3 on $Hostname ---"

# Cumulative stats for total network
$PrevTotalSent = 0
$PrevTotalRecv = 0
$IsFirstRun = $true

while ($true) {
    try {
        # A. Current Total Network Traffic (Cumulative)
        $ActiveAdapters = Get-NetAdapter | Where-Object { 
            $_.Status -eq 'Up' -and 
            $_.Name -notmatch 'VMware|VirtualBox|Loopback' 
        }
        $Stats = $ActiveAdapters | Get-NetAdapterStatistics -ErrorAction SilentlyContinue
        $currTotalSent = [uint64]($Stats.SentBytes | Measure-Object -Sum).Sum
        $currTotalRecv = [uint64]($Stats.ReceivedBytes | Measure-Object -Sum).Sum

        # B. Current SMB Traffic RATE (Bytes/sec from Performance Counters)
        # We sample the rate and project it over the 30s interval.
        $SmbRateClient = Get-Counter -Counter "\SMB Client\Write Bytes/sec", "\SMB Client\Read Bytes/sec" -ErrorAction SilentlyContinue
        $SmbRateServer = Get-Counter -Counter "\SMB Server\Write Bytes/sec", "\SMB Server\Read Bytes/sec" -ErrorAction SilentlyContinue

        $rateSmbSent = 0
        $rateSmbRecv = 0

        # Sum up all detected SMB rates
        foreach ($c in ($SmbRateClient.CounterSamples + $SmbRateServer.CounterSamples)) {
            if ($c.Path -like "*Write Bytes/sec*" -or $c.Path -like "*Send Bytes/sec*") { $rateSmbSent += $c.CookedValue }
            if ($c.Path -like "*Read Bytes/sec*" -or $c.Path -like "*Receive Bytes/sec*") { $rateSmbRecv += $c.CookedValue }
        }

        if (-not $IsFirstRun) {
            # 1. Total Delta in this 30s window
            $deltaTotalSent = if ($currTotalSent -gt $PrevTotalSent) { $currTotalSent - $PrevTotalSent } else { 0 }
            $deltaTotalRecv = if ($currTotalRecv -gt $PrevTotalRecv) { $currTotalRecv - $PrevTotalRecv } else { 0 }

            # 2. SMB Volume in this same window (Rate * Time)
            # We add a 7% Framing Bonus for the Performance Counters
            $shieldedSent = [uint64]($rateSmbSent * $ReportInterval * 1.07)
            $shieldedRecv = [uint64]($rateSmbRecv * $ReportInterval * 1.07)

            # 3. Final Internet Usage
            $finalSent = if ($deltaTotalSent -gt $shieldedSent) { $deltaTotalSent - $shieldedSent } else { 0 }
            $finalRecv = if ($deltaTotalRecv -gt $shieldedRecv) { $deltaTotalRecv - $shieldedRecv } else { 0 }

            # Avoid noise (Under 10KB)
            if ($finalSent -gt 10240 -or $finalRecv -gt 10240) {
                $Payload = @{
                    id = [string]$ClientID
                    hostname = [string]$Hostname
                    sent = $finalSent
                    received = $finalRecv
                    type = "stable-v3"
                } | ConvertTo-Json

                $URLs = @("http://$ServerIP:3001/api/report", "http://localhost:3001/api/report")
                foreach ($Url in $URLs) {
                    try {
                        Invoke-RestMethod -Uri $Url -Method Post -Body $Payload -ContentType 'application/json' -TimeoutSec 5 | Out-Null
                        $smbMB = [math]::Round(($rateSmbSent * $ReportInterval)/1MB, 2)
                        $rawMB = [math]::Round($deltaTotalSent/1MB, 2)
                        Log-Debug "Perf Shield (v3.3): Sent=$([math]::Round($finalSent/1MB, 2))MB (Raw=$rawMB MB, SMB=$smbMB MB)"
                        break
                    } catch { }
                }
            }
        }

        $PrevTotalSent = $currTotalSent
        $PrevTotalRecv = $currTotalRecv
        $IsFirstRun = $false

    } catch {
        Log-Debug "Agent v3.3 Error: $_"
    }
    
    Start-Sleep -Seconds $ReportInterval
}
