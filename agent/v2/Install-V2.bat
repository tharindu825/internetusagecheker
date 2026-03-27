@echo off
:: Install-V2.bat
:: This script performs a clean installation of the High-Precision Internet Usage Agent (v2).

echo --- Installing Internet Usage Agent v2 ---

:: 1. Elevation Check
net session >nul 2>&1 || (
    echo.
    echo ERROR: This script must be run as Administrator.
    echo Please right-click and select 'Run as Administrator'.
    echo.
    pause
    exit /b
)

:: 2. Terminate old agents
echo Killing any old agent processes...
powershell.exe -Command "Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like '*WmiInternetAgent*' -or $_.CommandLine -like '*InternetAgent_v2*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }"
schtasks /stop /tn "WindowsInternetUsageTrackerStable" /f 2>$null
schtasks /delete /tn "WindowsInternetUsageTrackerStable" /f 2>$null

:: 3. Create local directory (C:\InternetUsageTracker)
set "LOCAL_DIR=C:\InternetUsageTracker"
if not exist "%LOCAL_DIR%" (
    echo Creating local directory: %LOCAL_DIR%...
    mkdir "%LOCAL_DIR%"
)

:: 4. Mirror the v2 script to local path
echo Mirroring Agent v2 to local directory...
copy /y "%~dp0InternetAgent_v2.ps1" "%LOCAL_DIR%\InternetAgent_v2.ps1"

:: 5. Register the Background Task (v2)
echo Registering High-Precision Agent (v2) in background...
set "AGENT_PATH=%LOCAL_DIR%\InternetAgent_v2.ps1"
set "TASK_NAME=WindowsInternetUsageTrackerV2"

:: Cleanup old V2 task if exists
schtasks /stop /tn "%TASK_NAME%" /f 2>$null
schtasks /delete /tn "%TASK_NAME%" /f 2>$null

:: Register the new V2 task
powershell.exe -Command "$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-ExecutionPolicy Bypass -WindowStyle Hidden -File ""%AGENT_PATH%""'; $trigger = New-ScheduledTaskTrigger -AtLogOn; $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable; Register-ScheduledTask -TaskName '%TASK_NAME%' -Action $action -Trigger $trigger -Settings $settings -User 'SYSTEM' -RunLevel Highest -Force"

:: 6. Start the Agent
echo Starting Agent v2...
schtasks /run /tn "%TASK_NAME%"

echo.
echo --- SUCCESS ---
echo Internet Usage Agent v2 is now installed and running.
echo Data will be mirrored to: %LOCAL_DIR%
echo server: 192.168.1.32:3001
echo.
pause
