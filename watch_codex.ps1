$ErrorActionPreference = "SilentlyContinue"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$widgetScript = Join-Path $scriptDir "codex_widget.ps1"

function Test-WidgetRunning {
    $needle = [Regex]::Escape($widgetScript)
    $processes = Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe' OR Name = 'pwsh.exe'"
    return [bool]($processes | Where-Object { $_.CommandLine -match $needle })
}

function Start-Widget {
    Start-Process -WindowStyle Hidden -FilePath powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -STA -File `"$widgetScript`""
}

while ($true) {
    $codexRunning = Get-Process -Name "Codex", "codex" -ErrorAction SilentlyContinue
    if ($codexRunning -and -not (Test-WidgetRunning)) {
        Start-Widget
    }
    Start-Sleep -Seconds 5
}
