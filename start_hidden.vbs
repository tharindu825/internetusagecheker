' start_hidden.vbs (Updated with Absolute Paths)
' This script starts the Internet Usage Tracker Server and Dashboard in the absolute background.

Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
strPath = fso.GetParentFolderName(WScript.ScriptFullName)

' 1. Start Server in the absolute background
WshShell.CurrentDirectory = strPath & "\server"
WshShell.Run "cmd /c node index.js", 0, False

' 2. Start Dashboard in the absolute background
WshShell.CurrentDirectory = strPath & "\dashboard"
WshShell.Run "cmd /c npm run dev", 0, False

' Done!
' MsgBox "Internet Usage Tracker is now running in the background.", 64, "Background Started"
