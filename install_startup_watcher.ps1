$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$watcher = Join-Path $scriptDir "watch_codex.ps1"
$startup = [Environment]::GetFolderPath("Startup")
$shortcutPath = Join-Path $startup "Codex Status Tool Watcher.lnk"

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = "powershell.exe"
$shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$watcher`""
$shortcut.WorkingDirectory = $scriptDir
$shortcut.IconLocation = "powershell.exe,0"
$shortcut.Save()

Write-Output "Installed startup watcher: $shortcutPath"
