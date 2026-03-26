@echo off
echo Stopping Internet Usage Tracker infrastructure...

:: Kill node processes running the server and dashboard
taskkill /f /im node.exe

echo.
echo All background Node processes have been stopped.
pause
