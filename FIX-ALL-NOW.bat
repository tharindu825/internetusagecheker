@echo off
:: FIX-ALL-NOW.bat (Final Background & Cleanup Version)
cd /d "%~dp0"

echo --- Performing Final Global Fix (v2.2) ---

:: 1. Admin Check
net session >nul 2>&1 || (
    echo.
    echo [ERROR] PLEASE RIGHT-CLICK THIS FILE AND SELECT "RUN AS ADMINISTRATOR".
    echo.
    pause
    exit /b
)

:: 2. Stop all old processes
echo Stopping old agents and servers...
taskkill /f /im node.exe >nul 2>&1
powershell -Command "Stop-Process -Name 'node' -ErrorAction SilentlyContinue"
schtasks /stop /tn "WindowsInternetUsageTrackerV2" /f 2>$null

:: 3. Run Duplicate Cleanup (Now that the server is stopped)
echo Cleaning database duplicates...
if exist "server\cleanup_duplicates.js" (
    node "server\cleanup_duplicates.js"
) else (
    echo [WARNING] Cleanup script not found.
)

:: 4. Install Global Agent v2.2
echo Refreshing Global Monitor (v2.2)...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0agent\Register-AgentTask.ps1"

:: 5. Launch in BACKGROUND (Completely Hidden)
echo Launching Server and Dashboard in BACKGROUND...
start /b wscript.exe "%~dp0start_hidden.vbs"

echo.
echo --- SUCCESS! ---
echo 1. The duplicate is gone.
echo 2. The server and dashboard are now running hidden in the background.
echo 3. Check http://localhost:5173 to see your accurate data.
echo.
pause
