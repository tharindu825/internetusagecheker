Set WshShell = CreateObject("WScript.Shell")

' Kill existing node processes to ensure new code is loaded
WshShell.Run "taskkill /F /IM node.exe /T", 0, True

' Start Backend Server (Hidden)
WshShell.CurrentDirectory = "f:\Onedrive\Tharindu\Researches\InternetUsage_Checker\internetusagecheker\server"
WshShell.Run "cmd /c node index.js", 0, False

' Start Frontend Dashboard (Hidden)
WshShell.CurrentDirectory = "f:\Onedrive\Tharindu\Researches\InternetUsage_Checker\internetusagecheker\dashboard"
WshShell.Run "cmd /c npm run dev", 0, False

MsgBox "Internet Usage Tracker is now starting SILENTLY in the background." & vbCrLf & _
       "Dashboard: http://localhost:5173" & vbCrLf & _
       "Server: Port 3001", 64, "Status"
