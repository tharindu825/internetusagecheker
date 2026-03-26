@echo off
echo Starting Internet Usage Tracker...

:: Start Server in a new window
echo Starting Backend Server...
start "Usage Tracker Server" cmd /c "cd server && npm install && node index.js"

:: Start Dashboard in a new window
echo Starting Frontend Dashboard...
start "Usage Tracker Dashboard" cmd /c "cd dashboard && npm install && npm run dev"

echo.
echo Both components should be starting in separate windows.
echo Dashboard will be available at http://localhost:5173 once started.
echo Server is running on port 3001.
pause
