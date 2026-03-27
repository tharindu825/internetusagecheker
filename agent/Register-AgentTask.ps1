# Register-AgentTask.ps1 (v2.2 Global Monitor)
# This script mirrors the agent to C:\InternetUsageTracker and registers it as a SYSTEM task.

$LOCAL_DIR = "C:\InternetUsageTracker"
$AGENT_FILE = "InternetAgent_v2.ps1"
$SOURCE_PATH = Join-Path $PSScriptRoot "v2\$AGENT_FILE"
$DEST_PATH = Join-Path $LOCAL_DIR $AGENT_FILE

# 1. Mirroring
if (-not (Test-Path $LOCAL_DIR)) { New-Item -Path $LOCAL_DIR -ItemType Directory -Force }
Copy-Item -Path $SOURCE_PATH -Destination $DEST_PATH -Force

# 2. Registration
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File ""$DEST_PATH"""
$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

# Unregister old tasks if they exist
Unregister-ScheduledTask -TaskName "WindowsInternetUsageTracker" -Confirm:$false -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName "WindowsInternetUsageTrackerV2" -Confirm:$false -ErrorAction SilentlyContinue

Register-ScheduledTask -TaskName "WindowsInternetUsageTrackerV2" -Action $Action -Principal $Principal -Force
schtasks /run /tn "WindowsInternetUsageTrackerV2"

Write-Host "--- SUCCESS: Global Monitor v2.2 is now installed and running as SYSTEM ---" -ForegroundColor Green
