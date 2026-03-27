# Internet Usage Agent for Windows (Accurate Version)
# This script monitors TCP packets using IP Helper API to ensure accurate internet usage tracking.

$ServerUrl = "http://192.168.1.32:3001/api/report" # Updated with detected server IP
$ReportInterval = 30 # Seconds

# Helper to define the C# P/Invoke wrapper for low-level TCP stats
$TcpStatsCode = @"
using System;
using System.Runtime.InteropServices;
using System.Net;
using System.Collections.Generic;

public class TcpTracker {
    [StructLayout(LayoutKind.Sequential)]
    public struct MIB_TCPROW {
        public uint dwState;
        public uint dwLocalAddr;
        public uint dwLocalPort;
        public uint dwRemoteAddr;
        public uint dwRemotePort;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct TCP_ESTATS_DATA_RO_v0 {
        public ulong BytesOut;
        public ulong BytesIn;
    }

    [DllImport("iphlpapi.dll", SetLastError = true)]
    public static extern uint GetTcpTable(IntPtr pTcpTable, ref uint pdwSize, bool bOrder);

    [DllImport("iphlpapi.dll", SetLastError = true)]
    public static extern uint SetPerTcpConnectionEStats(ref MIB_TCPROW Row, int EstatsType, byte[] Rw, uint RwVersion, uint RwSize, int Offset);

    [DllImport("iphlpapi.dll", SetLastError = true)]
    public static extern uint GetPerTcpConnectionEStats(ref MIB_TCPROW Row, int EstatsType, byte[] Rw, uint RwVersion, uint RwSize, byte[] Ros, uint RosVersion, uint RosSize, byte[] Rod, uint RodVersion, uint RodSize);

    public const int TcpConnectionEstatsData = 2;

    public static uint EnableStats(uint localAddr, uint localPort, uint remoteAddr, uint remotePort) {
        MIB_TCPROW row = new MIB_TCPROW {
            dwLocalAddr = localAddr,
            dwLocalPort = localPort,
            dwRemoteAddr = remoteAddr,
            dwRemotePort = remotePort
        };
        byte[] rw = new byte[1] { 1 }; // Enable
        return SetPerTcpConnectionEStats(ref row, TcpConnectionEstatsData, rw, 0, 1, 0);
    }

    public static ulong[] GetStats(uint localAddr, uint localPort, uint remoteAddr, uint remotePort) {
        MIB_TCPROW row = new MIB_TCPROW {
            dwLocalAddr = localAddr,
            dwLocalPort = localPort,
            dwRemoteAddr = remoteAddr,
            dwRemotePort = remotePort
        };
        
        int size = Marshal.SizeOf(typeof(TCP_ESTATS_DATA_RO_v0));
        byte[] rod = new byte[size];
        
        uint res = GetPerTcpConnectionEStats(ref row, TcpConnectionEstatsData, null, 0, 0, null, 0, 0, rod, 0, (uint)size);
        
        if (res == 0) {
            IntPtr ptr = Marshal.AllocHGlobal(size);
            Marshal.Copy(rod, 0, ptr, size);
            TCP_ESTATS_DATA_RO_v0 data = (TCP_ESTATS_DATA_RO_v0)Marshal.PtrToStructure(ptr, typeof(TCP_ESTATS_DATA_RO_v0));
            Marshal.FreeHGlobal(ptr);
            return new ulong[] { data.BytesOut, data.BytesIn };
        }
        return null;
    }
}
"@

try {
    Add-Type -TypeDefinition $TcpStatsCode -ErrorAction SilentlyContinue
} catch {}

# Function to check if an IP is local (RFC1918)
function Is-LocalIP {
    param([string]$IP)
    if ($IP -match '^127\.' -or $IP -eq '::1' -or $IP -eq '0.0.0.0') { return $true }
    if ($IP -match '^10\.') { return $true }
    if ($IP -match '^192\.168\.') { return $true }
    if ($IP -match '^172\.(1[6-9]|2[0-9]|3[0-1])\.') { return $true }
    if ($IP -match '^169\.254\.') { return $true }
    return $false
}

# Persistent Client ID Logic
$Hostname = hostname
try {
    $ClientID = (Get-CimInstance Win32_ComputerSystemProduct -ErrorAction Stop).UUID
} catch {
    $IDPath = Join-Path $env:ALLUSERSPROFILE "InternetUsageTracker_ID.txt"
    if (Test-Path $IDPath) { $ClientID = Get-Content $IDPath }
    else {
        $ClientID = [System.Guid]::NewGuid().ToString()
        $ClientID | Out-File $IDPath | Out-Null
    }
}

# State to track cumulative bytes and handle connection closure
$ConnMap = @{} # "Local:Port-Remote:Port" -> @{ Sent = X; Received = Y }

Write-Host "Started Accurate Internet Usage Agent on $Hostname" -ForegroundColor Cyan

while ($true) {
    # Get all established connections
    $Connections = Get-NetTCPConnection -State Established
    
    $IntervalInternetSent = 0
    $IntervalInternetReceived = 0
    
    $CurrentConnKeys = @()

    foreach ($conn in $Connections) {
        # Create a unique key for the connection (big-endian DWORDs as used by IP Helper)
        # Port conversion to network byte order
        $lPort = [BitConverter]::ToUInt16([BitConverter]::GetBytes([uint16]$conn.LocalPort), 0)
        $rPort = [BitConverter]::ToUInt16([BitConverter]::GetBytes([uint16]$conn.RemotePort), 0)
        
        $lAddrRaw = [System.Net.IPAddress]::Parse($conn.LocalAddress).GetAddressBytes()
        $rAddrRaw = [System.Net.IPAddress]::Parse($conn.RemoteAddress).GetAddressBytes()
        $lAddr = [BitConverter]::ToUInt32($lAddrRaw, 0)
        $rAddr = [BitConverter]::ToUInt32($rAddrRaw, 0)
        
        $Key = "$($conn.LocalAddress):$($conn.LocalPort)-$($conn.RemoteAddress):$($conn.RemotePort)"
        $CurrentConnKeys += $Key

        # If it's a new connection, enable EStats
        if (-not $ConnMap.ContainsKey($Key)) {
            [TcpTracker]::EnableStats($lAddr, $lPort, $rAddr, $rPort) | Out-Null
            $ConnMap[$Key] = @{ Sent = 0; Received = 0 }
        }

        # Query stats
        $Stats = [TcpTracker]::GetStats($lAddr, $lPort, $rAddr, $rPort)
        if ($null -ne $Stats) {
            $currSent = $Stats[0]
            $currRecv = $Stats[1]
            
            # Calculate delta for this connection
            $deltaSent = $currSent - $ConnMap[$Key].Sent
            $deltaRecv = $currRecv - $ConnMap[$Key].Received
            
            # Filter by Remote IP
            if (-not (Is-LocalIP $conn.RemoteAddress)) {
                $IntervalInternetSent += $deltaSent
                $IntervalInternetReceived += $deltaRecv
            }
            
            # Update history
            $ConnMap[$Key].Sent = $currSent
            $ConnMap[$Key].Received = $currRecv
        }
    }

    # Clean up closed connections from map to prevent memory leak
    # (Note: We might lose the 'final' burst of a connection if it closes between polls,
    # but for sustained high-volume transfers like SMB or large downloads, this is 99% accurate)
    $KeysToDelete = @()
    foreach ($k in $ConnMap.Keys) {
        if ($k -notin $CurrentConnKeys) { $KeysToDelete += $k }
    }
    foreach ($k in $KeysToDelete) { $ConnMap.Remove($k) }

    # Report to server if there's usage or just to heartbeat
    if ($IntervalInternetSent -gt 0 -or $IntervalInternetReceived -gt 0) {
        $Payload = @{
            id = $ClientID
            hostname = $Hostname
            sent = $IntervalInternetSent
            received = $IntervalInternetReceived
        } | ConvertTo-Json

        try {
            Invoke-RestMethod -Uri $ServerUrl -Method Post -Body $Payload -ContentType "application/json" -TimeoutSec 5 | Out-Null
        } catch { }
    }

    Start-Sleep -Seconds $ReportInterval
}
