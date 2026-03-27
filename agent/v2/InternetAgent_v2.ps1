# InternetUsageAgent v3.0 (Identity Lock + SMB Shield)
# tracks "True Internet" across ALL active adapters (Ethernet, VPN, Wi-Fi).
# Uses Cumulative SMB Protocol Counters for perfect "Local vs Internet" separation.

$ServerIP = "192.168.1.32"
$Port = "3001"
$ReportInterval = 30 # Seconds

# 1. State & Identity Lock (HOSTNAME is the Master ID)
$Hostname = hostname
$ClientID = "$Hostname-v3" # Locked ID to computer name

# 2. Path & Auto-Mirror Logic
$LocalDir = "C:\InternetUsageTracker"
$LogPath = Join-Path $LocalDir "agent_v3_debug.txt"
if (-not (Test-Path $LocalDir)) { New-Item -Path $LocalDir -ItemType Directory -Force | Out-Null }

function Log-Debug {
    param([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$Timestamp] $Message" | Out-File -FilePath $LogPath -Append -Encoding utf8
}

Log-Debug "--- Starting Identity Lock v3.0 on $Hostname ---"

# Global state to track cumulative bytes across ALL interfaces
$PrevSent = @{} # Dictionary: Alias -> Bytes
$PrevRecv = @{}
$PrevSmbSent = @{}
$PrevSmbRecv = @{}
$IsFirstRun = $true

while ($true) {
    try {
        # A. Find ALL active physical and VPN adapters
        $ActiveAdapters = Get-NetAdapter | Where-Object { 
            $_.Status -eq 'Up' -and 
            $_.Name -notmatch 'VMware|VirtualBox|Loopback' 
        }

        # B. Get Cumulative SMB Stats (Client + Server)
        # This is the "SMB Shield" - much more accurate than per-second rates.
        $SmbClientStats = Get-SmbClientNetworkInterface -ErrorAction SilentlyContinue
        $SmbServerStats = Get-SmbServerNetworkInterface -ErrorAction SilentlyContinue

        $TotalInternetSent = 0
        $TotalInternetRecv = 0

        foreach ($adapter in $ActiveAdapters) {
            $name = $adapter.Name
            $stats = Get-NetAdapterStatistics -Name $name -ErrorAction SilentlyContinue
            if ($null -eq $stats) { continue }

            $currTotalSent = $stats.SentBytes
            $currTotalRecv = $stats.ReceivedBytes

            # Find matching SMB stats for THIS adapter
            # SMB Client "Sent" is actually "Write" traffic
            $adaptSmbClient = $SmbClientStats | Where-Object { $_.InterfaceAlias -eq $name }
            $adaptSmbServer = $SmbServerStats | Where-Object { $_.InterfaceAlias -eq $name }

            # TOTAL SMB BYTES on this interface
            $currSmbSent = [uint64](($adaptSmbClient.BytesSent | Measure-Object -Sum).Sum + ($adaptSmbServer.BytesSent | Measure-Object -Sum).Sum)
            $currSmbRecv = [uint64](($adaptSmbClient.BytesReceived | Measure-Object -Sum).Sum + ($adaptSmbServer.BytesReceived | Measure-Object -Sum).Sum)

            if (-not $IsFirstRun -and $PrevSent.ContainsKey($name)) {
                # 1. Calculate the raw deltas
                $deltaTotalSent = [uint64][math]::Max(0, $currTotalSent - $PrevSent[$name])
                $deltaTotalRecv = [uint64][math]::Max(0, $currTotalRecv - $PrevRecv[$name])
                
                # 2. Calculate the SMB deltas
                $deltaSmbSent = [uint64][math]::Max(0, $currSmbSent - $PrevSmbSent[$name])
                $deltaSmbRecv = [uint64][math]::Max(0, $currSmbRecv - $PrevSmbRecv[$name])

                # 3. Final Internet Delta = Total - SMB
                $finalSent = [uint64][math]::Max(0, $deltaTotalSent - $deltaSmbSent)
                $finalRecv = [uint64][math]::Max(0, $deltaTotalRecv - $deltaSmbRecv)
                
                $TotalInternetSent += $finalSent
                $TotalInternetRecv += $finalRecv
            }

            # Update history for next delta
            $PrevSent[$name] = $currTotalSent
            $PrevRecv[$name] = $currTotalRecv
            $PrevSmbSent[$name] = $currSmbSent
            $PrevSmbRecv[$name] = $currSmbRecv
        }

        if (-not $IsFirstRun) {
            # Avoid reporting tiny noise (Under 10KB total)
            if ($TotalInternetSent -gt 10240 -or $TotalInternetRecv -gt 10240) {
                $Payload = @{
                    id = [string]$ClientID
                    hostname = [string]$Hostname
                    sent = $TotalInternetSent
                    received = $TotalInternetRecv
                    type = "stable-v3"
                } | ConvertTo-Json

                # Reporting with Fallback
                $URLs = @("http://$ServerIP`:$Port/api/report", "http://localhost:$Port/api/report")
                foreach ($Url in $URLs) {
                    try {
                        Invoke-RestMethod -Uri $Url -Method Post -Body $Payload -ContentType 'application/json' -TimeoutSec 5 | Out-Null
                        Log-Debug "Identity Lock Report: Sent=$([math]::Round($TotalInternetSent/1MB, 2))MB Recv=$([math]::Round($TotalInternetRecv/1MB, 2))MB"
                        break
                    } catch { }
                }
            }
        }

        $IsFirstRun = $false
    } catch {
        Log-Debug "SMB Shield Error: $_"
    }
    
    Start-Sleep -Seconds $ReportInterval
}
