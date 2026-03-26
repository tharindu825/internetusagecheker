# Internet Usage Agent for Windows
# This script monitors network traffic and reports internet usage (excluding local LAN) to a central server.

$ServerUrl = "http://YOUR_SERVER_IP:3001/api/report" # Update this with the actual server IP
$ReportInterval = 30 # Seconds

# Function to check if an IP is local (RFC1918)
function Is-LocalIP {
    param([string]$IP)
    if ($IP -match '^127\.' -or $IP -eq '::1') { return $true }
    if ($IP -match '^10\.') { return $true }
    if ($IP -match '^192\.168\.') { return $true }
    if ($IP -match '^172\.(1[6-9]|2[0-9]|3[0-1])\.') { return $true }
    if ($IP -match '^169\.254\.') { return $true }
    return $false
}

$Hostname = hostname
$ClientID = [System.Guid]::NewGuid().ToString() # In a real scenario, use a persistent ID like Serial Number or MAC
if (Test-Path "$env:TEMP\usage_client_id.txt") {
    $ClientID = Get-Content "$env:TEMP\usage_client_id.txt"
} else {
    $ClientID | Out-File "$env:TEMP\usage_client_id.txt"
}

Write-Host "Starting Internet Usage Agent (ID: $ClientID)..."

# Initialize counters
$TotalSent = 0
$TotalReceived = 0

# Initial baseline
$LastStats = Get-NetAdapterStatistics | Select-Object Name, ReceivedBytes, SentBytes

while ($true) {
    Start-Sleep -Seconds $ReportInterval

    $CurrentStats = Get-NetAdapterStatistics | Select-Object Name, ReceivedBytes, SentBytes
    
    # Calculate delta for the interval
    $DiffSent = 0
    $DiffReceived = 0
    
    foreach ($stat in $CurrentStats) {
        $last = $LastStats | Where-Object { $_.Name -eq $stat.Name }
        if ($last) {
            $DiffSent += ($stat.SentBytes - $last.SentBytes)
            $DiffReceived += ($stat.ReceivedBytes - $last.ReceivedBytes)
        }
    }
    $LastStats = $CurrentStats

    # --- HEURISTIC FILTERING ---
    # Since capturing per-packet IP in real-time without drivers is intensive,
    # we use a heuristic: we sample active connections and estimate the "Internet Ratio".
    
    $Connections = Get-NetTCPConnection -State Established
    $LocalBytes = 0
    $InternetBytes = 0
    
    $LocalCount = 0
    $InternetCount = 0
    
    foreach ($conn in $Connections) {
        if (Is-LocalIP $conn.RemoteAddress) {
            $LocalCount++
        } else {
            $InternetCount++
        }
    }
    
    $TotalCount = $LocalCount + $InternetCount
    $InternetRatio = 1.0
    if ($TotalCount -gt 0) {
        $InternetRatio = $InternetCount / $TotalCount
    }

    # Apply ratio to the total delta
    # Note: This is an estimation. For "Real" tracking, ETW or Npcap is needed.
    # However, to avoid complexity of binary dependencies, this ratio-based approach
    # provides a good approximation of internet vs local load.
    
    $EstimatedInternetSent = [Math]::Round($DiffSent * $InternetRatio)
    $EstimatedInternetReceived = [Math]::Round($DiffReceived * $InternetRatio)

    # Report to server
    $Payload = @{
        id = $ClientID
        hostname = $Hostname
        sent = $EstimatedInternetSent
        received = $EstimatedInternetReceived
    } | ConvertTo-Json

    try {
        Invoke-RestMethod -Uri $ServerUrl -Method Post -Body $Payload -ContentType "application/json" -ErrorAction Stop
        Write-Host "Reported: Sent=$($EstimatedInternetSent)B, Recv=$($EstimatedInternetReceived)B (Ratio: $($InternetRatio))"
    } catch {
        Write-Warning "Failed to report to server: $($_.Exception.Message)"
    }
}
