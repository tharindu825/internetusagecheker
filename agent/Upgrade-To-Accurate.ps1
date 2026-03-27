# Upgrade-To-Accurate.ps1
# This script upgrades an old agent to the new high-precision version.

$AgentFolder = "C:\Inusage_agent"
$TaskName = "WindowsInternetUsageTracker"

Write-Host "--- Automated Agent Upgrade ---" -ForegroundColor Cyan

# 1. Check for Administrator privileges
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "ERROR: This script must be run as Administrator."
    exit
}

# 2. Stop all current agent activity
Write-Host "Stopping existing agent processes..."
# Target specifically powershell processes running the agent script to avoid killing this upgrade script
Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like "*InternetUsageAgent*" -and $_.Name -like "*powershell*" } | ForEach-Object { 
    Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue 
}
& schtasks /stop /tn $TaskName /f 2>$null | Out-Null

# 3. Ensure folder exists
if (-not (Test-Path $AgentFolder)) { 
    New-Item -ItemType Directory -Path $AgentFolder | Out-Null
}

# 4. Check if we have the new script file here (in the same folder as this upgrade script)
$NewScriptSource = Join-Path $PSScriptRoot "InternetUsageAgent.ps1"
$NewScriptDest = Join-Path $AgentFolder "InternetUsageAgent.ps1"

if (Test-Path $NewScriptSource) {
    Write-Host "Copying new agent script to $AgentFolder..."
    Copy-Item $NewScriptSource $NewScriptDest -Force
    Unblock-File $NewScriptDest -ErrorAction SilentlyContinue
} else {
    Write-Warning "New InternetUsageAgent.ps1 not found in $PSScriptRoot. Skipping copy."
}

# 5. Re-register the task using the existing InstallAgent.bat logic
Write-Host "Re-starting the background task..."
$InstallBat = Join-Path $PSScriptRoot "InstallAgent.bat"
if (Test-Path $InstallBat) {
    Start-Process -FilePath cmd.exe -ArgumentList "/c $InstallBat" -Wait -Verb RunAs
}

# 6. Final start
& schtasks /run /tn $TaskName | Out-Null

Write-Host "`nUpgrade Complete! CTP1804 should now be accurate." -ForegroundColor Green
Write-Host "Returning to Dashboard in 3 seconds..."
Start-Sleep -Seconds 3
