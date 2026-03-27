# InternetUsageAgent v2.2 (Global Network Monitor)
# tracks "True Internet" across ALL active adapters (Ethernet, VPN, Wi-Fi) simultaneously.
# Self-healing: mirrors itself to C:\InternetUsageTracker for stability.

$ServerIP = "192.168.1.32"
$Port = "3001"
$ReportInterval = 30 # Seconds

# 1. State & Client ID (Stable UUID)
$Hostname = hostname
try {
    $ClientID = ([guid]((Get-CimInstance Win32_ComputerSystemProduct -ErrorAction Stop).UUID)).ToString()
} catch {
    $IDPath = Join-Path $env:ALLUSERSPROFILE "InternetUsageTracker_ID.txt"
    if (Test-Path $IDPath) { $ClientID = Get-Content $IDPath }
    else {
        $ClientID = [System.Guid]::NewGuid().ToString()
        $ClientID | Out-File $IDPath | Out-Null
    }
}

# 2. Path & Auto-Mirror Logic
$LocalDir = "C:\InternetUsageTracker"
$LogPath = Join-Path $LocalDir "agent_v2_debug.txt"
if (-not (Test-Path $LocalDir)) { New-Item -Path $LocalDir -ItemType Directory -Force | Out-Null }

function Log-Debug {
    param([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$Timestamp] $Message" | Out-File -FilePath $LogPath -Append -Encoding utf8
}

Log-Debug "--- Starting Global Monitor v2.2 on $Hostname ---"
Log-Debug "Tracking ID: $ClientID"

# Global state to track cumulative bytes across ALL interfaces
$PrevSent = @{} # Dictionary: Alias -> Bytes
$PrevRecv = @{}
$IsFirstRun = $true

while ($true) {
    try {
        # A. Find ALL active network adapters (Physical + VPN)
        # We explicitly ignore VMware/VirtualBox 'Loop' adapters to avoid double-counting
        $ActiveAdapters = Get-NetAdapter | Where-Object { 
            $_.Status -eq 'Up' -and 
            $_.Name -notmatch 'VMware|VirtualBox|Loopback' 
        }

        $TotalSentDelta = 0
        $TotalRecvDelta = 0

        foreach ($adapter in $ActiveAdapters) {
            $name = $adapter.Name
            $stats = Get-NetAdapterStatistics -Name $name -ErrorAction SilentlyContinue
            if ($null -eq $stats) { continue }

            $currSent = $stats.SentBytes
            $currRecv = $stats.ReceivedBytes

            if (-not $IsFirstRun -and $PrevSent.ContainsKey($name)) {
                $deltaSent = [uint64][math]::Max(0, $currSent - $PrevSent[$name])
                $deltaRecv = [uint64][math]::Max(0, $currRecv - $PrevRecv[$name])
                
                $TotalSentDelta += $deltaSent
                $TotalRecvDelta += $deltaRecv
            }

            # Update history for next delta
            $PrevSent[$name] = $currSent
            $PrevRecv[$name] = $currRecv
        }

        # B. Local SMB Subtraction (Global PC Subtraction)
        $smbClient = Get-CimInstance Win32_PerfRawData_Counters_SMBClientShares | Where-Object { $_.Name -eq "_Total" }
        $currSmbClientWrite = if ($smbClient) { $smbClient.WriteBytesPersec } else { 0 }
        $currSmbClientRead = if ($smbClient) { $smbClient.ReadBytesPersec } else { 0 }

        $smbServer = Get-CimInstance Win32_PerfRawData_Counters_SMBServer
        $currSmbServerWrite = if ($smbServer) { $smbServer.WriteBytesPersec } else { 0 }
        $currSmbServerRead = if ($smbServer) { $smbServer.ReadBytesPersec } else { 0 }

        if (-not $IsFirstRun) {
            $deltaSmbSent = [uint64][math]::Max(0, ($currSmbClientWrite - $PrevSmbClientWrite) + ($currSmbServerRead - $PrevSmbServerRead))
            $deltaSmbRecv = [uint64][math]::Max(0, ($currSmbClientRead - $PrevSmbClientRead) + ($currSmbServerWrite - $PrevSmbServerWrite))

            # Final Filtered Global Result (Total - SMB)
            $finalSent = [uint64][math]::Max(0, $TotalSentDelta - $deltaSmbSent)
            $finalRecv = [uint64][math]::Max(0, $TotalRecvDelta - $deltaSmbRecv)

            # Avoid reporting tiny noise
            if ($finalSent -gt 5120 -or $finalRecv -gt 5120) {
                $Payload = @{
                    id = [string]$ClientID
                    hostname = [string]$Hostname
                    sent = $finalSent
                    received = $finalRecv
                    type = "stable-v2"
                } | ConvertTo-Json

                # Reporting with Fallback
                $URLs = @("http://$ServerIP`:$Port/api/report", "http://localhost:$Port/api/report")
                foreach ($Url in $URLs) {
                    try {
                        Invoke-RestMethod -Uri $Url -Method Post -Body $Payload -ContentType "application/json" -TimeoutSec 5 | Out-Null
                        Log-Debug "Global Report: Sent=$([math]::Round($finalSent/1MB, 2))MB Recv=$([math]::Round($finalRecv/1MB, 2))MB (Adapters=$($ActiveAdapters.Count))"
                        break
                    } catch { }
                }
            }
        }

        # Save SMB for next delta
        $PrevSmbClientWrite = $currSmbClientWrite
        $PrevSmbClientRead = $currSmbClientRead
        $PrevSmbServerWrite = $currSmbServerWrite
        $PrevSmbServerRead = $currSmbServerRead
        $IsFirstRun = $false

    } catch {
        Log-Debug "Global Monitor Error: $_"
    }
    
    Start-Sleep -Seconds $ReportInterval
}
