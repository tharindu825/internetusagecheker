# Internet Usage Agent for Windows
# This script monitors network traffic and reports internet usage (excluding local LAN) to a central server.

$ServerUrl = "http://192.168.1.32:3001/api/report" # Updated with detected server IP
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
# Use Hardware UUID for persistent identification across reboots and temp clears
try {
    $ClientID = (Get-CimInstance Win32_ComputerSystemProduct -ErrorAction Stop).UUID
} catch {
    # Fallback to random if UUID fails, but store in a more persistent location
    $IDPath = Join-Path $env:ALLUSERSPROFILE "InternetUsageTracker_ID.txt"
    if (Test-Path $IDPath) {
        $ClientID = Get-Content $IDPath
    } else {
        $ClientID = [System.Guid]::NewGuid().ToString()
        New-Item -ItemType Directory -Path (Split-Path $IDPath) -Force | Out-Null
        $ClientID | Out-File $IDPath | Out-Null
    }
}

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
    $Connections = Get-NetTCPConnection -State Established
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
        Invoke-RestMethod -Uri $ServerUrl -Method Post -Body $Payload -ContentType "application/json" -ErrorAction Stop | Out-Null
    } catch {
        # Silently ignore errors in background
    }
}
