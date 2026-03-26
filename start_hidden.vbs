Set WshShell = CreateObject("WScript.Shell")

' Start Server hidden
WshShell.Run "cmd /c cd server && node index.js", 0, False

' Start Dashboard hidden
WshShell.Run "cmd /c cd dashboard && npm run dev", 0, False

MsgBox "Internet Usage Tracker Server and Dashboard are now running in the background." & vbCrLf & _
       "Server Port: 3001" & vbCrLf & _
       "Dashboard: http://localhost:5173", vbInformation, "Tracker Started"
