@echo off
echo Stopping Internet Usage Agent...

:: Stop the scheduled task
powershell.exe -Command "Stop-ScheduledTask -TaskName WindowsInternetUsageTracker -ErrorAction SilentlyContinue"

:: Also kill any direct PowerShell processes running the script
powershell.exe -Command "Get-Process powershell* | Where-Object { $_.CommandLine -like '*InternetUsageAgent*' } | Stop-Process -Force -ErrorAction SilentlyContinue"

echo.
echo Agent has been stopped. (It will still restart on next boot unless you unregister it).
echo To fully UNREGISTER the agent, run: powershell -Command "Unregister-ScheduledTask -TaskName WindowsInternetUsageTracker -Confirm:$false"
pause
