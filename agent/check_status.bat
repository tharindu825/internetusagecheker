@echo off
setlocal enabledelayedexpansion
echo Checking Internet Usage Agent status...
echo.

:: Check Scheduled Task Status
powershell.exe -Command "$task = Get-ScheduledTask -TaskName WindowsInternetUsageTracker -ErrorAction SilentlyContinue; if ($task) { Write-Host 'Scheduled Task: Found' -ForegroundColor Green; Write-Host 'State: ' -NoNewline; Write-Host $task.State -ForegroundColor Cyan } else { Write-Host 'Scheduled Task: NOT FOUND (Run InstallAgent.bat to fix)' -ForegroundColor Red }"

:: Improved Process Detection (Checking both Task-launched and Manual-launched instances)
powershell.exe -Command "$procs = Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like '*InternetUsageAgent*' -and $_.Name -like '*powershell*' } -ErrorAction SilentlyContinue; if ($procs) { foreach ($p in $procs) { Write-Host 'Agent Process: RUNNING (PID: ' -NoNewline; Write-Host $p.ProcessId -NoNewline; Write-Host ')' -ForegroundColor Green; Write-Host '   Command: ' -NoNewline; Write-Host $p.CommandLine -ForegroundColor Gray } } else { Write-Host 'Agent Process: NOT RUNNING' -ForegroundColor Yellow }"

echo.
echo --- Quick Guide ---
echo * To START background task: Run InstallAgent.bat (As Admin)
echo * To START hidden now:     Run Start-Agent-Background.bat (As Admin)
echo * To STOP all agents:      Run stop_agent.bat (As Admin)
echo.
pause
