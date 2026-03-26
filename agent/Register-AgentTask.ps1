# Register-AgentTask.ps1
# Updated version using schtasks for better compatibility

$ScriptName = "InternetUsageAgent.ps1"
$ScriptBase = $PSScriptRoot
$ScriptPath = Join-Path $ScriptBase $ScriptName
$TaskName = "WindowsInternetUsageTracker"

# Check for Administrator privileges
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "ERROR: This script must be run as Administrator."
    Write-Host "Please right-click PowerShell and select 'Run as Administrator'." -ForegroundColor Red
    exit
}

# Check if script exists
if (-not (Test-Path $ScriptPath)) {
    Write-Error "Could not find $ScriptName at $ScriptPath"
    exit
}

Write-Host "Registering $TaskName as a background task..." -ForegroundColor Cyan

# Use schtasks.exe for better reliability across Windows versions
# /SC ONSTART : Run at startup
# /RU SYSTEM : Run as SYSTEM (background)
# /RL HIGHEST: Highest privileges
# /NP: Do not create a password prompt (important for SYSTEM)
$Command = "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptPath`""

# Force delete if exists
& schtasks /delete /tn $TaskName /f 2>&1 | Out-Null

# Create task
& schtasks /create /tn $TaskName /tr $Command /sc onstart /ru SYSTEM /rl HIGHEST /f

if ($LASTEXITCODE -eq 0) {
    Write-Host "Successfully registered!" -ForegroundColor Green
    Write-Host "The agent will now run in the background on every system startup."
    Write-Host "To start it manually right now, run:"
    Write-Host "schtasks /run /tn $TaskName" -ForegroundColor Yellow
} else {
    Write-Error "Failed to register task using schtasks. Error code: $LASTEXITCODE"
}
