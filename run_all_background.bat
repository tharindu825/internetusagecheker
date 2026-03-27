@echo off
:: Restarts the Internet Usage Tracker in the background (Hidden)
:: Ensures new code is loaded correctly.

echo Restarting Internet Usage Tracker in BACKGROUND...
cscript //nologo start_silent.vbs

echo.
echo Components started silently.
echo Please allow 30 seconds for the Dashboard to appear at http://localhost:5173
pause
