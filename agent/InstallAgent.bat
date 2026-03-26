@echo off
:: Check for administrative privileges
net session >nul 2>&1
if %errorLevel% == 0 (
    echo Running with administrator privileges...
) else (
    echo ERROR: Please right-click this file and select "Run as Administrator".
    pause
    exit /b
)

echo Registering Internet Usage Agent in background...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0Register-AgentTask.ps1"

echo.
if %errorLevel% == 0 (
    echo Registration complete!
) else (
    echo Registration failed.
)
pause
