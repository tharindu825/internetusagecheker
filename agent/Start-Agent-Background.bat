@echo off
:: Start the Internet Usage Agent in the background (hidden)
:: Requires Administrator privileges to access network stats

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: Please right-click this file and select "Run as Administrator".
    pause
    exit /b
)

echo Starting Internet Usage Agent in background...
powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File "%~dp0InternetUsageAgent.ps1"

echo.
echo Agent started successfully in background!
echo You can close this window now.
echo Use check_status.bat to verify it's running.
timeout /t 5
