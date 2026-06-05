$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$widget = Join-Path $scriptDir "codex_widget.ps1"
$codexAppId = "OpenAI.Codex_2p2nqsd0c76g0!App"

function Test-WidgetRunning {
    $needle = [Regex]::Escape($widget)
    $processes = Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe' OR Name = 'pwsh.exe'" -ErrorAction SilentlyContinue
    return [bool]($processes | Where-Object { $_.CommandLine -match $needle })
}

if (-not (Test-WidgetRunning)) {
    Start-Process -WindowStyle Hidden -FilePath powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -STA -File `"$widget`""
}

Start-Process "shell:AppsFolder\$codexAppId"
