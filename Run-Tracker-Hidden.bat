@echo off
:: This script launches the tracker infrastructure in the background with zero windows remaining open
echo Launching Internet Usage Tracker in background...
start /b wscript.exe "%~dp0start_hidden.vbs"
exit
