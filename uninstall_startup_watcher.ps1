$ErrorActionPreference = "Stop"

$startup = [Environment]::GetFolderPath("Startup")
$shortcutPath = Join-Path $startup "Codex Status Tool Watcher.lnk"

if (Test-Path $shortcutPath) {
    Remove-Item -LiteralPath $shortcutPath
    Write-Output "Removed startup watcher: $shortcutPath"
} else {
    Write-Output "Startup watcher was not installed."
}
