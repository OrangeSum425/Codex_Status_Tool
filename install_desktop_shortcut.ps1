$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$launcher = Join-Path $scriptDir "launch_codex_with_widget.ps1"
$desktop = [Environment]::GetFolderPath("Desktop")
$shortcutPath = Join-Path $desktop "Codex with Status.lnk"

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = "powershell.exe"
$shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$launcher`""
$shortcut.WorkingDirectory = $scriptDir
$shortcut.IconLocation = "$env:LOCALAPPDATA\OpenAI\Codex\bin\fb2111b91430cb17\codex.exe,0"
$shortcut.Save()

Write-Output "Installed desktop shortcut: $shortcutPath"
