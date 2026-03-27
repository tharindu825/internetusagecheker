@echo off
:: Check for administrative privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: Please right-click this file and select "Run as Administrator".
    pause
    exit /b
)

echo --- Upgrading Agent to Accurate Version ---
echo.

:: Run the PowerShell upgrade script
powershell.exe -ExecutionPolicy Bypass -File "%~dp0Upgrade-To-Accurate.ps1"

echo.
if %errorLevel% == 0 (
    echo.
    echo Upgrade Complete! CTP1804 should now be accurate.
) else (
    echo.
    echo Upgrade failed. Error level: %errorLevel%
)
pause
