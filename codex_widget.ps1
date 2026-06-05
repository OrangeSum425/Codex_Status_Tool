Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$StateFile = Join-Path $ScriptDir "widget_state.json"
$CodexSessionsDir = Join-Path $env:USERPROFILE ".codex\sessions"

$DefaultState = [ordered]@{
    five_hour_percent = -1
    weekly_percent = -1
    reset_seconds = -1
    weekly_reset = "--"
}

function Get-State {
    if (Test-Path $StateFile) {
        try {
            $loaded = Get-Content -LiteralPath $StateFile -Raw -Encoding UTF8 | ConvertFrom-Json
            $five = if ($null -ne $loaded.five_hour_percent) { [int]$loaded.five_hour_percent } else { $DefaultState.five_hour_percent }
            $weekly = if ($null -ne $loaded.weekly_percent) { [int]$loaded.weekly_percent } else { $DefaultState.weekly_percent }
            $reset = if ($null -ne $loaded.reset_seconds) { [int]$loaded.reset_seconds } else { $DefaultState.reset_seconds }
            $weeklyReset = if ($null -ne $loaded.weekly_reset) { [string]$loaded.weekly_reset } else { $DefaultState.weekly_reset }
            return [ordered]@{
                five_hour_percent = $five
                weekly_percent = $weekly
                reset_seconds = $reset
                weekly_reset = $weeklyReset
            }
        } catch {
            return $DefaultState.Clone()
        }
    }

    return $DefaultState.Clone()
}

function Save-State {
    param($State)
    $State | ConvertTo-Json | Set-Content -LiteralPath $StateFile -Encoding UTF8
}

function Format-ResetDate {
    param([long]$UnixSeconds)
    if ($UnixSeconds -le 0) {
        return "--"
    }

    return [DateTimeOffset]::FromUnixTimeSeconds($UnixSeconds).ToLocalTime().ToString("MMM d", [System.Globalization.CultureInfo]::InvariantCulture)
}

function Seconds-Until {
    param([long]$UnixSeconds)
    if ($UnixSeconds -le 0) {
        return -1
    }

    $now = [DateTimeOffset]::Now.ToUnixTimeSeconds()
    return [Math]::Max(0, [int]($UnixSeconds - $now))
}

function Get-LatestCodexRateLimits {
    if (-not (Test-Path $CodexSessionsDir)) {
        return $null
    }

    $latest = $null
    $files = Get-ChildItem $CodexSessionsDir -Recurse -Filter "rollout-*.jsonl" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 40

    foreach ($file in $files) {
        foreach ($line in Get-Content -LiteralPath $file.FullName -ErrorAction SilentlyContinue) {
            if ($line -notlike '*"type":"token_count"*' -or $line -notlike '*"rate_limits"*') {
                continue
            }

            try {
                $entry = $line | ConvertFrom-Json
                $limits = $entry.payload.rate_limits
                if ($null -eq $limits -or $null -eq $limits.primary -or $null -eq $limits.secondary) {
                    continue
                }

                $timestamp = [DateTimeOffset]::Parse([string]$entry.timestamp)
                if ($null -eq $latest -or $timestamp -gt $latest.Timestamp) {
                    $latest = [pscustomobject]@{
                        Timestamp = $timestamp
                        Limits = $limits
                    }
                }
            } catch {
            }
        }
    }

    return $latest
}

function Sync-CodexRateLimits {
    $latest = Get-LatestCodexRateLimits
    if ($null -eq $latest) {
        return $false
    }

    $primary = $latest.Limits.primary
    $secondary = $latest.Limits.secondary

    $State.five_hour_percent = Limit-Percent ([int][Math]::Round(100 - [double]$primary.used_percent))
    $State.weekly_percent = Limit-Percent ([int][Math]::Round(100 - [double]$secondary.used_percent))
    $State.reset_seconds = Seconds-Until ([long]$primary.resets_at)
    $State.weekly_reset = Format-ResetDate ([long]$secondary.resets_at)
    Save-State $State
    return $true
}

function Limit-Percent {
    param([int]$Value)
    return [Math]::Max(0, [Math]::Min(100, $Value))
}

function Format-Countdown {
    param([int]$Seconds)
    $Seconds = [Math]::Max(0, $Seconds)
    $span = [TimeSpan]::FromSeconds($Seconds)
    return "{0:00}:{1:00}:{2:00}" -f [Math]::Floor($span.TotalHours), $span.Minutes, $span.Seconds
}

function Get-Accent {
    param([int]$Five, [int]$Weekly)
    if ($Five -lt 0) { return "#2F3A4C" }
    if ($Five -lt 20) { return "#FF7D93" }
    if ($Weekly -lt 25 -or $Five -lt 45) { return "#F6C568" }
    return "#7BE495"
}

$Xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="300" Height="132" WindowStyle="None" ResizeMode="NoResize"
        AllowsTransparency="True" Background="Transparent" Topmost="True"
        ShowInTaskbar="False" FontFamily="Microsoft YaHei UI">
  <Window.Resources>
    <DropShadowEffect x:Key="PanelShadow" BlurRadius="24" ShadowDepth="8" Opacity="0.32"/>
  </Window.Resources>
  <Border CornerRadius="16" Background="#111823" BorderBrush="#344154" BorderThickness="1" Effect="{StaticResource PanelShadow}" SnapsToDevicePixels="True">
    <Grid Margin="12,10,12,10">
      <Grid.RowDefinitions>
        <RowDefinition Height="18"/>
        <RowDefinition Height="*"/>
      </Grid.RowDefinitions>

      <Grid Grid.Row="0" Name="DragArea">
        <TextBlock Text="CODEX" Foreground="#91A0B5" FontSize="10" FontWeight="Bold" VerticalAlignment="Top"/>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Top">
          <Button Name="CloseButton" Content="X" Width="20" Height="20" FontSize="10" FontWeight="Bold"
                  Foreground="#EEF4FF" Background="#202938" BorderBrush="#344154"/>
        </StackPanel>
      </Grid>

      <StackPanel Grid.Row="1" Margin="0,8,0,0">
        <Grid Height="40" Margin="0,0,0,8">
          <Grid.RowDefinitions>
            <RowDefinition Height="24"/>
            <RowDefinition Height="6"/>
          </Grid.RowDefinitions>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="44"/>
            <ColumnDefinition Width="58"/>
            <ColumnDefinition/>
          </Grid.ColumnDefinitions>
          <TextBlock Text="5h" Foreground="#91A0B5" FontSize="12" FontWeight="Bold" VerticalAlignment="Center"/>
          <TextBlock Name="FivePercentText" Grid.Column="1" Foreground="#EEF4FF" FontSize="18" FontWeight="Bold" VerticalAlignment="Center"/>
          <TextBlock Name="FiveResetText" Grid.Column="2" Foreground="#AAB6C7" FontSize="11" FontWeight="Bold" HorizontalAlignment="Right" VerticalAlignment="Center"/>
          <Grid Grid.Row="1" Grid.ColumnSpan="3" Height="5" VerticalAlignment="Bottom">
            <Border Background="#2F3A4C" CornerRadius="3"/>
            <Border Name="FiveBar" Background="#7BE495" CornerRadius="3" HorizontalAlignment="Left" Width="0"/>
          </Grid>
        </Grid>

        <Grid Height="40">
          <Grid.RowDefinitions>
            <RowDefinition Height="24"/>
            <RowDefinition Height="6"/>
          </Grid.RowDefinitions>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="44"/>
            <ColumnDefinition Width="58"/>
            <ColumnDefinition/>
          </Grid.ColumnDefinitions>
          <TextBlock Text="Week" Foreground="#91A0B5" FontSize="12" FontWeight="Bold" VerticalAlignment="Center"/>
          <TextBlock Name="WeeklyPercentText" Grid.Column="1" Foreground="#EEF4FF" FontSize="18" FontWeight="Bold" VerticalAlignment="Center"/>
          <TextBlock Name="WeeklyResetText" Grid.Column="2" Foreground="#AAB6C7" FontSize="11" FontWeight="Bold" HorizontalAlignment="Right" VerticalAlignment="Center"/>
          <Grid Grid.Row="1" Grid.ColumnSpan="3" Height="5" VerticalAlignment="Bottom">
            <Border Background="#2F3A4C" CornerRadius="3"/>
            <Border Name="WeeklyBar" Background="#7BE495" CornerRadius="3" HorizontalAlignment="Left" Width="0"/>
          </Grid>
        </Grid>
      </StackPanel>
    </Grid>
  </Border>
</Window>
"@

$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($Xaml))
$Window = [Windows.Markup.XamlReader]::Load($reader)

$State = Get-State
$SyncTick = 0
$BrushConverter = [System.Windows.Media.BrushConverter]::new()

function Find-Control($Name) {
    return $Window.FindName($Name)
}

function Render {
    $fiveRaw = [int]$State.five_hour_percent
    $weeklyRaw = [int]$State.weekly_percent
    $five = if ($fiveRaw -lt 0) { -1 } else { Limit-Percent $fiveRaw }
    $weekly = if ($weeklyRaw -lt 0) { -1 } else { Limit-Percent $weeklyRaw }
    $accent = Get-Accent $five $weekly

    (Find-Control "FivePercentText").Text = if ($five -lt 0) { "--" } else { "$five%" }
    (Find-Control "WeeklyPercentText").Text = if ($weekly -lt 0) { "--" } else { "$weekly%" }
    if ([int]$State.reset_seconds -lt 0) {
        (Find-Control "FiveResetText").Text = "reset --"
    } else {
        (Find-Control "FiveResetText").Text = "reset " + (Format-Countdown ([int]$State.reset_seconds))
    }
    $weeklyReset = [string]$State.weekly_reset
    if ([string]::IsNullOrWhiteSpace($weeklyReset) -or $weeklyReset -eq "n/a") {
        $weeklyReset = "--"
    }
    (Find-Control "WeeklyResetText").Text = "reset " + $weeklyReset

    $barWidth = 276
    (Find-Control "FiveBar").Width = if ($five -lt 0) { 0 } else { [Math]::Round($barWidth * $five / 100) }
    (Find-Control "WeeklyBar").Width = if ($weekly -lt 0) { 0 } else { [Math]::Round($barWidth * $weekly / 100) }
    (Find-Control "FiveBar").Background = $BrushConverter.ConvertFromString($accent)
}

function Show-UpdateDialog {
    $DialogXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="360" Height="244" WindowStyle="ToolWindow" ResizeMode="NoResize"
        Topmost="True" Background="#111823" FontFamily="Microsoft YaHei UI">
  <Grid Margin="16">
    <Grid.RowDefinitions>
      <RowDefinition Height="26"/>
      <RowDefinition Height="90"/>
      <RowDefinition Height="34"/>
      <RowDefinition Height="*"/>
    </Grid.RowDefinitions>
    <TextBlock Text="Paste /status or enter percentages" Foreground="#91A0B5" FontSize="12" FontWeight="Bold"/>
    <TextBox Name="StatusInput" Grid.Row="1" AcceptsReturn="True" TextWrapping="Wrap" Padding="10,8"
             Background="#0A0F17" Foreground="#EEF4FF" BorderBrush="#344154"
             Text=""/>
    <TextBox Name="WeeklyInput" Grid.Row="2" Margin="0,8,0,0" Padding="10,4"
             Background="#0A0F17" Foreground="#EEF4FF" BorderBrush="#344154"
             Text="weekly reset: n/a"/>
    <Button Name="DialogUpdate" Grid.Row="3" Content="Update" Height="34" VerticalAlignment="Bottom"
            Background="#223044" Foreground="#EEF4FF" BorderBrush="#344154" FontWeight="Bold"/>
  </Grid>
</Window>
"@
    $dialogReader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($DialogXaml))
    $dialog = [Windows.Markup.XamlReader]::Load($dialogReader)
    $dialog.Left = $Window.Left + 18
    $dialog.Top = $Window.Top + 74
    $input = $dialog.FindName("StatusInput")
    $weeklyInput = $dialog.FindName("WeeklyInput")
    $button = $dialog.FindName("DialogUpdate")
    $weeklyInput.Text = "weekly reset: " + [string]$State.weekly_reset

    $button.Add_Click({
        $text = $input.Text
        if ($text -match "(?:5h|five)[^\d]*(\d{1,3})\s*%") {
            $State.five_hour_percent = Limit-Percent ([int]$Matches[1])
        }
        if ($text -match "(?:week|weekly)[^\d]*(\d{1,3})\s*%") {
            $State.weekly_percent = Limit-Percent ([int]$Matches[1])
        }
        if ($text -match "(\d+)\s*h(?:ours?)?\s*(\d+)?\s*m?") {
            $hours = [int]$Matches[1]
            $minutes = if ($Matches[2]) { [int]$Matches[2] } else { 0 }
            $State.reset_seconds = $hours * 3600 + $minutes * 60
        }
        if ($weeklyInput.Text -match "weekly reset:\s*(.+)$") {
            $State.weekly_reset = $Matches[1].Trim()
        }
        Save-State $State
        Render
        $dialog.Close()
    })

    [void]$dialog.ShowDialog()
}

(Find-Control "CloseButton").Add_Click({ $Window.Close() })
(Find-Control "DragArea").Add_MouseLeftButtonDown({ $Window.DragMove() })
$Window.Add_MouseRightButtonUp({
    $menu = [System.Windows.Controls.ContextMenu]::new()
    $update = [System.Windows.Controls.MenuItem]::new()
    $update.Header = "Update /status"
    $update.Add_Click({ Show-UpdateDialog })
    $topmost = [System.Windows.Controls.MenuItem]::new()
    $topmost.Header = "Toggle topmost"
    $topmost.Add_Click({ $Window.Topmost = -not $Window.Topmost })
    $close = [System.Windows.Controls.MenuItem]::new()
    $close.Header = "Exit"
    $close.Add_Click({ $Window.Close() })
    [void]$menu.Items.Add($update)
    [void]$menu.Items.Add($topmost)
    [void]$menu.Items.Add($close)
    $menu.IsOpen = $true
})

$timer = [System.Windows.Threading.DispatcherTimer]::new()
$timer.Interval = [TimeSpan]::FromSeconds(1)
$timer.Add_Tick({
    if ([int]$State.reset_seconds -ge 0) {
        $State.reset_seconds = [Math]::Max(0, [int]$State.reset_seconds - 1)
    }
    $script:SyncTick += 1
    if ($script:SyncTick -ge 30) {
        $script:SyncTick = 0
        [void](Sync-CodexRateLimits)
    }
    Render
})
$timer.Start()

[void](Sync-CodexRateLimits)
Render
[void]$Window.ShowDialog()
Save-State $State
