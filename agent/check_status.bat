@echo off
echo Checking Internet Usage Agent status...
echo.

:: Check Scheduled Task Status
powershell.exe -Command "$task = Get-ScheduledTask -TaskName WindowsInternetUsageTracker -ErrorAction SilentlyContinue; if ($task) { Write-Host 'Scheduled Task: Found' -ForegroundColor Green; Write-Host 'State: ' -NoNewline; Write-Host $task.State -ForegroundColor Cyan } else { Write-Host 'Scheduled Task: NOT FOUND' -ForegroundColor Red }"

:: Check if the process is actually running right now
powershell.exe -Command "$proc = Get-Process powershell* | Where-Object { $_.CommandLine -like '*InternetUsageAgent*' } -ErrorAction SilentlyContinue; if ($proc) { Write-Host 'Agent Process: RUNNING (PID: ' -NoNewline; Write-Host $proc.Id -NoNewline; Write-Host ')' -ForegroundColor Green } else { Write-Host 'Agent Process: NOT RUNNING' -ForegroundColor Yellow }"

echo.
echo --- Quick Guide ---
echo * To START the agent: Run InstallAgent.bat
echo * To STOP the agent:  Run stop_agent.bat
echo * To VIEW usage: Check the Dashboard at http://192.168.1.32:5173
echo.
pause
