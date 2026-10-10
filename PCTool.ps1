<#
 PCTool GUI - PC Checker (VirusTotal) + Windows/Gaming Optimizer
 Run (any cmd, it asks for admin itself and the console stays open):
   powershell -NoExit -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/Cash101212/PCTool/main/PCTool.ps1 | iex"
 (Upload this file to GitHub as PCTool.ps1)
#>

$Script:Url = 'https://raw.githubusercontent.com/Cash101212/PCTool/main/PCTool.ps1'
$Host.UI.RawUI.WindowTitle = 'PCTool - console (keep open)'

function Step([int]$pct, [string]$msg) {
    $w = 30; $f = [int]($w * $pct / 100)
    $bar = ('#' * $f) + ('-' * ($w - $f))
    Write-Host ("  [{0}] {1,3}%  {2}" -f $bar, $pct, $msg) -ForegroundColor Cyan
}

function Test-Admin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

Write-Host ''
Write-Host '  ========== PCTool ==========' -ForegroundColor Magenta
Write-Host ''
Step 0 'Starting...'

# Self-elevate: relaunch the same GitHub command as admin (new console, stays open)
if (-not (Test-Admin)) {
    Write-Host '  Not running as admin - asking Windows for permission (UAC prompt)...' -ForegroundColor Yellow
    try {
        $cmd = "irm $Script:Url | iex"
        Start-Process powershell -Verb RunAs -ArgumentList "-NoExit -NoProfile -ExecutionPolicy Bypass -Command `"$cmd`"" -ErrorAction Stop
        Write-Host '  Admin window launched. You can close this one.' -ForegroundColor Green
    } catch {
        Write-Host '  [ERROR] Could not get admin rights (UAC was cancelled or blocked).' -ForegroundColor Red
        Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
        Write-Host '  Fix: right-click cmd > Run as administrator, then run the command again.' -ForegroundColor Yellow
    }
    return
}

$ErrorActionPreference = 'Stop'   # while loading, any problem is reported clearly
try {
Step 5 'Running as administrator'
Step 15 'Loading Windows UI libraries...'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

Step 30 'Preparing data folder...'
$Script:Dir = Join-Path $env:APPDATA 'PCTool'
New-Item -ItemType Directory -Force -Path $Script:Dir | Out-Null
$Script:CacheFile = Join-Path $Script:Dir 'vt-cache.json'
$Script:KeyFile   = Join-Path $Script:Dir 'vt.key'
$Script:Cancel = $false

# ================================================================== XAML
$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="PCTool" Width="1100" Height="740" MinWidth="920" MinHeight="620"
        WindowStartupLocation="CenterScreen" WindowStyle="None" AllowsTransparency="True"
        Background="Transparent" FontFamily="Segoe UI" ResizeMode="CanResizeWithGrip">
  <Window.Resources>
    <Style x:Key="BtnAccent" TargetType="Button">
      <Setter Property="Foreground" Value="White"/><Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Cursor" Value="Hand"/><Setter Property="Margin" Value="0,0,10,0"/>
      <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button">
        <Border x:Name="b" Background="#7C5CFF" CornerRadius="8" Padding="18,10">
          <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
        <ControlTemplate.Triggers>
          <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Background" Value="#907AFF"/></Trigger>
          <Trigger Property="IsEnabled" Value="False"><Setter TargetName="b" Property="Opacity" Value="0.35"/></Trigger>
        </ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter>
    </Style>
    <Style x:Key="BtnGhost" TargetType="Button">
      <Setter Property="Foreground" Value="#E6E8EF"/><Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Margin" Value="0,0,10,0"/>
      <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button">
        <Border x:Name="b" Background="#232838" CornerRadius="8" Padding="16,10">
          <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
        <ControlTemplate.Triggers>
          <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Background" Value="#2E3550"/></Trigger>
          <Trigger Property="IsEnabled" Value="False"><Setter TargetName="b" Property="Opacity" Value="0.35"/></Trigger>
        </ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter>
    </Style>
    <Style x:Key="BtnNav" TargetType="Button">
      <Setter Property="Foreground" Value="#B5BACB"/><Setter Property="FontSize" Value="14"/>
      <Setter Property="Cursor" Value="Hand"/><Setter Property="Margin" Value="0,0,0,6"/>
      <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button">
        <Border x:Name="b" Background="Transparent" CornerRadius="10" Padding="16,12">
          <ContentPresenter HorizontalAlignment="Left" VerticalAlignment="Center"/></Border>
        <ControlTemplate.Triggers>
          <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Background" Value="#1D2130"/></Trigger>
          <Trigger Property="Tag" Value="active"><Setter TargetName="b" Property="Background" Value="#2A2F4A"/>
            <Setter Property="Foreground" Value="White"/></Trigger>
        </ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter>
    </Style>
    <Style TargetType="CheckBox"><Setter Property="Foreground" Value="#E6E8EF"/><Setter Property="FontSize" Value="14"/></Style>
  </Window.Resources>

  <Border Background="#0F1117" CornerRadius="14" BorderBrush="#232838" BorderThickness="1">
    <Grid>
      <Grid.ColumnDefinitions><ColumnDefinition Width="230"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>

      <!-- Sidebar -->
      <Border Background="#141722" CornerRadius="14,0,0,14" Padding="16,20">
        <DockPanel>
          <StackPanel DockPanel.Dock="Top" Margin="6,0,0,28">
            <TextBlock Text="PCTool" FontSize="26" FontWeight="Bold" Foreground="White"/>
            <TextBlock Text="check  •  protect  •  boost" FontSize="11" Foreground="#7C5CFF" Margin="2,2,0,0"/>
          </StackPanel>
          <TextBlock DockPanel.Dock="Bottom" x:Name="AdminTag" Foreground="#5E647A" FontSize="11" Margin="8,0,0,0"/>
          <StackPanel>
            <Button x:Name="NavDash"  Style="{StaticResource BtnNav}" Content="🏠   Dashboard"/>
            <Button x:Name="NavScan"  Style="{StaticResource BtnNav}" Content="🛡   Virus Scanner"/>
            <Button x:Name="NavOpt"   Style="{StaticResource BtnNav}" Content="⚡   Optimizer"/>
            <Button x:Name="NavStart" Style="{StaticResource BtnNav}" Content="🚀   Startup Apps"/>
          </StackPanel>
        </DockPanel>
      </Border>

      <!-- Main -->
      <Grid Grid.Column="1">
        <Grid.RowDefinitions><RowDefinition Height="46"/><RowDefinition Height="*"/><RowDefinition Height="150"/></Grid.RowDefinitions>

        <Grid x:Name="TitleBar" Background="Transparent">
          <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,8,12,0">
            <Button x:Name="BtnMin" Style="{StaticResource BtnGhost}" Content="—" Padding="0" Width="36" Height="28" Margin="0,0,6,0"/>
            <Button x:Name="BtnClose" Style="{StaticResource BtnGhost}" Content="✕" Padding="0" Width="36" Height="28" Margin="0"/>
          </StackPanel>
        </Grid>

        <Grid Grid.Row="1" Margin="28,0,28,0">
          <!-- Dashboard -->
          <ScrollViewer x:Name="PgDash" VerticalScrollBarVisibility="Auto">
            <StackPanel>
              <TextBlock Text="Dashboard" FontSize="28" FontWeight="Bold" Foreground="White"/>
              <TextBlock Text="Live health of your PC" Foreground="#8A90A2" Margin="0,2,0,18"/>
              <StackPanel Orientation="Horizontal" Margin="0,0,0,18">
                <Button x:Name="BtnRefresh" Style="{StaticResource BtnAccent}" Content="Refresh"/>
                <Button x:Name="BtnDefender" Style="{StaticResource BtnGhost}" Content="Defender update + quick scan"/>
              </StackPanel>
              <WrapPanel x:Name="Cards"/>
            </StackPanel>
          </ScrollViewer>

          <!-- Scanner -->
          <Grid x:Name="PgScan" Visibility="Collapsed">
            <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
            <StackPanel>
              <TextBlock Text="Virus Scanner" FontSize="28" FontWeight="Bold" Foreground="White"/>
              <TextBlock Text="Checks file hashes on VirusTotal. Files are never uploaded." Foreground="#8A90A2" Margin="0,2,0,14"/>
            </StackPanel>
            <Border Grid.Row="1" Background="#1B1F2B" CornerRadius="10" Padding="14" Margin="0,0,0,12">
              <DockPanel>
                <TextBlock DockPanel.Dock="Left" Text="API key" Foreground="#8A90A2" VerticalAlignment="Center" Margin="0,0,12,0"/>
                <Button DockPanel.Dock="Right" x:Name="BtnSaveKey" Style="{StaticResource BtnGhost}" Content="Save key" Margin="10,0,0,0" Padding="14,6"/>
                <CheckBox DockPanel.Dock="Right" x:Name="ChkPremium" Content="Premium key (no delay)" VerticalAlignment="Center" Margin="12,0,0,0"/>
                <PasswordBox x:Name="KeyBox" Background="#0F1117" Foreground="White" BorderBrush="#2E3550" Padding="8,6" VerticalContentAlignment="Center"/>
              </DockPanel>
            </Border>
            <StackPanel Grid.Row="2" Orientation="Horizontal" Margin="0,0,0,10">
              <Button x:Name="BtnScanSys" Style="{StaticResource BtnAccent}" Content="Scan my PC"/>
              <Button x:Name="BtnScanFile" Style="{StaticResource BtnGhost}" Content="Scan a file"/>
              <Button x:Name="BtnScanFolder" Style="{StaticResource BtnGhost}" Content="Scan a folder"/>
              <Button x:Name="BtnCancel" Style="{StaticResource BtnGhost}" Content="Cancel" IsEnabled="False"/>
              <Button x:Name="BtnOpenVT" Style="{StaticResource BtnGhost}" Content="Open on VirusTotal"/>
              <TextBlock x:Name="ScanSummary" Foreground="#8A90A2" VerticalAlignment="Center" Margin="6,0,0,0"/>
            </StackPanel>
            <Grid Grid.Row="3">
              <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
              <ProgressBar x:Name="Prog" Height="6" Background="#232838" Foreground="#7C5CFF" BorderThickness="0" Margin="0,0,0,10"/>
              <DataGrid x:Name="Results" Grid.Row="1" AutoGenerateColumns="False" IsReadOnly="True" CanUserAddRows="False"
                        Background="#1B1F2B" Foreground="#E6E8EF" RowBackground="#1B1F2B" AlternatingRowBackground="#1F2432"
                        BorderThickness="0" GridLinesVisibility="None" HeadersVisibility="Column" SelectionMode="Single">
                <DataGrid.ColumnHeaderStyle><Style TargetType="DataGridColumnHeader">
                  <Setter Property="Background" Value="#232838"/><Setter Property="Foreground" Value="#8A90A2"/>
                  <Setter Property="Padding" Value="12,8"/><Setter Property="BorderThickness" Value="0"/></Style></DataGrid.ColumnHeaderStyle>
                <DataGrid.RowStyle><Style TargetType="DataGridRow">
                  <Setter Property="Padding" Value="4"/>
                  <Style.Triggers>
                    <DataTrigger Binding="{Binding Verdict}" Value="Malicious"><Setter Property="Foreground" Value="#FF5C6C"/></DataTrigger>
                    <DataTrigger Binding="{Binding Verdict}" Value="Suspicious"><Setter Property="Foreground" Value="#F5B83D"/></DataTrigger>
                    <DataTrigger Binding="{Binding Verdict}" Value="Clean"><Setter Property="Foreground" Value="#2ECC71"/></DataTrigger>
                    <DataTrigger Binding="{Binding Verdict}" Value="Unknown"><Setter Property="Foreground" Value="#8A90A2"/></DataTrigger>
                  </Style.Triggers></Style></DataGrid.RowStyle>
                <DataGrid.Columns>
                  <DataGridTextColumn Header="Verdict" Binding="{Binding Verdict}" Width="100"/>
                  <DataGridTextColumn Header="Flagged" Binding="{Binding Flagged}" Width="90"/>
                  <DataGridTextColumn Header="File" Binding="{Binding Name}" Width="200"/>
                  <DataGridTextColumn Header="Path" Binding="{Binding File}" Width="*"/>
                </DataGrid.Columns>
              </DataGrid>
            </Grid>
          </Grid>

          <!-- Optimizer -->
          <Grid x:Name="PgOpt" Visibility="Collapsed">
            <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
            <StackPanel>
              <TextBlock Text="Optimizer" FontSize="28" FontWeight="Bold" Foreground="White"/>
              <TextBlock Text="Pick what you want. A restore point is made first so you can undo." Foreground="#8A90A2" Margin="0,2,0,14"/>
            </StackPanel>
            <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto"><StackPanel x:Name="TweakPanel"/></ScrollViewer>
            <StackPanel Grid.Row="2" Orientation="Horizontal" Margin="0,12,0,8">
              <Button x:Name="BtnApply" Style="{StaticResource BtnAccent}" Content="⚡  Apply selected"/>
              <Button x:Name="BtnAll" Style="{StaticResource BtnGhost}" Content="Select all"/>
              <Button x:Name="BtnNone" Style="{StaticResource BtnGhost}" Content="Select none"/>
            </StackPanel>
          </Grid>

          <!-- Startup -->
          <Grid x:Name="PgStart" Visibility="Collapsed">
            <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
            <StackPanel>
              <TextBlock Text="Startup Apps" FontSize="28" FontWeight="Bold" Foreground="White"/>
              <TextBlock Text="Tick the ones you don't need at boot. Removed entries are backed up." Foreground="#8A90A2" Margin="0,2,0,14"/>
            </StackPanel>
            <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto"><StackPanel x:Name="StartPanel"/></ScrollViewer>
            <StackPanel Grid.Row="2" Orientation="Horizontal" Margin="0,12,0,8">
              <Button x:Name="BtnDisableStart" Style="{StaticResource BtnAccent}" Content="Remove selected from startup"/>
              <Button x:Name="BtnReloadStart" Style="{StaticResource BtnGhost}" Content="Reload"/>
            </StackPanel>
          </Grid>
        </Grid>

        <!-- Log -->
        <Border Grid.Row="2" Background="#0B0D12" CornerRadius="0,0,14,0" Padding="14,8">
          <DockPanel>
            <TextBlock DockPanel.Dock="Top" x:Name="Status" Text="Ready" Foreground="#7C5CFF" FontSize="12" Margin="0,0,0,4"/>
            <RichTextBox x:Name="Log" Background="Transparent" BorderThickness="0" IsReadOnly="True"
                         VerticalScrollBarVisibility="Auto" FontFamily="Consolas" FontSize="12" Foreground="#B5BACB"/>
          </DockPanel>
        </Border>
      </Grid>
    </Grid>
  </Border>
</Window>
'@

Step 45 'Building the window...'
$win = [Windows.Markup.XamlReader]::Load([Xml.XmlReader]::Create([IO.StringReader]::new($xaml)))
Step 60 'Connecting controls...'
$UI = @{}
foreach ($n in 'TitleBar','BtnMin','BtnClose','NavDash','NavScan','NavOpt','NavStart','PgDash','PgScan','PgOpt','PgStart',
               'Cards','BtnRefresh','BtnDefender','KeyBox','BtnSaveKey','ChkPremium','BtnScanSys','BtnScanFile','BtnScanFolder',
               'BtnCancel','BtnOpenVT','ScanSummary','Prog','Results','TweakPanel','BtnApply','BtnAll','BtnNone',
               'StartPanel','BtnDisableStart','BtnReloadStart','Log','Status','AdminTag') {
    $UI[$n] = $win.FindName($n)
}
$UI.AdminTag.Text = 'Running as administrator'

# ================================================================== UI helpers
function Pump {
    $f = [Windows.Threading.DispatcherFrame]::new()
    $cb = [Windows.Threading.DispatcherOperationCallback]{ param($frame) $frame.Continue = $false; return $null }
    [void][Windows.Threading.Dispatcher]::CurrentDispatcher.BeginInvoke([Windows.Threading.DispatcherPriority]::Background, $cb, $f)
    [Windows.Threading.Dispatcher]::PushFrame($f)
}
function Wait-UI([double]$sec) {
    $end = (Get-Date).AddSeconds($sec)
    while ((Get-Date) -lt $end -and -not $Script:Cancel) { Pump; Start-Sleep -Milliseconds 60 }
}
function Brush($hex) { [Windows.Media.BrushConverter]::new().ConvertFromString($hex) }

function Log($msg, $level = 'info') {
    $c = switch ($level) { 'ok' {'#2ECC71'} 'warn' {'#F5B83D'} 'bad' {'#FF5C6C'} default {'#B5BACB'} }
    $cc = switch ($level) { 'ok' {'Green'} 'warn' {'Yellow'} 'bad' {'Red'} default {'Gray'} }
    Write-Host ("  [{0}] {1}" -f $level.ToUpper(), $msg) -ForegroundColor $cc
    $r = [Windows.Documents.Run]::new(("{0:HH:mm:ss}  {1}" -f (Get-Date), $msg))
    $r.Foreground = Brush $c
    $p = [Windows.Documents.Paragraph]::new($r); $p.Margin = [Windows.Thickness]::new(0)
    $UI.Log.Document.Blocks.Add($p); $UI.Log.ScrollToEnd(); Pump
}
function Set-Status($t) { $UI.Status.Text = $t; Pump }

function Set-Busy([bool]$b) {
    foreach ($n in 'BtnScanSys','BtnScanFile','BtnScanFolder','BtnApply','BtnRefresh','BtnDefender','BtnDisableStart') { $UI[$n].IsEnabled = -not $b }
    $UI.BtnCancel.IsEnabled = $b
}

function Show-Page($name) {
    $map = @{ Dash=@('PgDash','NavDash'); Scan=@('PgScan','NavScan'); Opt=@('PgOpt','NavOpt'); Start=@('PgStart','NavStart') }
    foreach ($k in $map.Keys) {
        $UI[$map[$k][0]].Visibility = if ($k -eq $name) { 'Visible' } else { 'Collapsed' }
        $UI[$map[$k][1]].Tag = if ($k -eq $name) { 'active' } else { '' }
    }
    if ($name -eq 'Start') { Load-Startup }
}

function Set-Reg($path, $name, $value, $type = 'DWord') {
    try {
        if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        New-ItemProperty -Path $path -Name $name -Value $value -PropertyType $type -Force | Out-Null
        return $true
    } catch { Log "Could not set $name : $($_.Exception.Message)" 'warn'; return $false }
}

# ================================================================== Dashboard
Step 70 'Building dashboard...'
$Script:CardVals = [ordered]@{}
function New-Card($title) {
    $x = @"
<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Background="#1B1F2B" CornerRadius="12" Width="220" Height="96" Margin="0,0,14,14" Padding="16,12">
  <StackPanel>
    <TextBlock Text="$title" Foreground="#8A90A2" FontSize="12"/>
    <TextBlock x:Name="v" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Text="..." Foreground="White" FontSize="15" FontWeight="SemiBold" TextWrapping="Wrap" Margin="0,8,0,0"/>
  </StackPanel>
</Border>
"@
    $b = [Windows.Markup.XamlReader]::Load([Xml.XmlReader]::Create([IO.StringReader]::new($x)))
    $UI.Cards.Children.Add($b) | Out-Null
    $Script:CardVals[$title] = ($b.Child.Children | Where-Object { $_.Name -eq 'v' })
}
foreach ($t in 'Windows','CPU','Graphics card','Memory','Storage','Defender','Firewall','Uptime / Startup') { New-Card $t }

function Set-Card($title, $text, $level = 'info') {
    $tb = $Script:CardVals[$title]; $tb.Text = $text
}

function Update-Dashboard {
    Set-Status 'Reading system info...'
    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $gpu = Get-CimInstance Win32_VideoController | Select-Object -First 1
    Set-Card 'Windows' "$($os.Caption -replace 'Microsoft ','')`nbuild $($os.BuildNumber)"
    Set-Card 'CPU' $cpu.Name
    $gd = ''; if ($gpu.DriverDate) { $gd = " - driver " + ([datetime]$gpu.DriverDate).ToString('yyyy-MM-dd') }
    Set-Card 'Graphics card' "$($gpu.Name)$gd"
    $tot = [math]::Round($os.TotalVisibleMemorySize/1MB,1); $free = [math]::Round($os.FreePhysicalMemory/1MB,1)
    Set-Card 'Memory' "$free GB free of $tot GB" $(if ($free -lt 2) {'bad'} elseif ($free -lt 4) {'warn'} else {'ok'})

    $parts = @(); $lvl = 'ok'
    Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object {
        $pct = [math]::Round($_.FreeSpace / $_.Size * 100)
        $parts += "$($_.DeviceID) $pct% free"
        if ($pct -lt 10) { $lvl = 'bad' } elseif ($pct -lt 20 -and $lvl -ne 'bad') { $lvl = 'warn' }
    }
    Set-Card 'Storage' ($parts -join '   ') $lvl

    try {
        $mp = Get-MpComputerStatus
        $age = ((Get-Date) - $mp.AntivirusSignatureLastUpdated).TotalDays
        if (-not $mp.RealTimeProtectionEnabled) { Set-Card 'Defender' 'Real-time protection OFF' 'bad' }
        elseif ($age -gt 3) { Set-Card 'Defender' ("On, signatures {0:N0} days old" -f $age) 'warn' }
        else { Set-Card 'Defender' 'On and up to date' 'ok' }
    } catch { Set-Card 'Defender' 'Unavailable (other antivirus?)' 'warn' }

    $fw = Get-NetFirewallProfile
    if ($fw | Where-Object { -not $_.Enabled }) { Set-Card 'Firewall' 'A profile is OFF' 'bad' } else { Set-Card 'Firewall' 'All profiles ON' 'ok' }

    $up = (Get-Date) - $os.LastBootUpTime
    $sc = 0
    foreach ($k in 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run','HKLM:\Software\Microsoft\Windows\CurrentVersion\Run') {
        if (Test-Path $k) { $sc += @((Get-ItemProperty $k).PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' }).Count }
    }
    Set-Card 'Uptime / Startup' ("{0:N1} days up, $sc startup apps" -f $up.TotalDays) $(if ($up.TotalDays -gt 7 -or $sc -gt 10) {'warn'} else {'ok'})
    Set-Status 'Ready'
}

function Invoke-DefenderScan {
    Set-Busy $true; $Script:Cancel = $false
    try {
        Log 'Updating Defender signatures...'; Set-Status 'Updating signatures...'
        try { Update-MpSignature -ErrorAction Stop } catch { Log $_.Exception.Message 'warn' }
        Log 'Running quick scan (this can take a few minutes)...'; Set-Status 'Defender quick scan running...'
        $j = Start-MpScan -ScanType QuickScan -AsJob
        while ($j.State -eq 'Running') { Pump; Start-Sleep -Milliseconds 250 }
        Remove-Job $j -Force -ErrorAction SilentlyContinue
        $t = @(Get-MpThreat -ErrorAction SilentlyContinue)
        if ($t.Count) { foreach ($x in $t) { Log "Threat: $($x.ThreatName)" 'bad' } } else { Log 'Scan finished. No threats found.' 'ok' }
    } catch { Log $_.Exception.Message 'bad' }
    Set-Status 'Ready'; Set-Busy $false
}

# ================================================================== VirusTotal
function Get-VTKey {
    if (Test-Path $Script:KeyFile) {
        try { $s = Get-Content $Script:KeyFile | ConvertTo-SecureString; return [Net.NetworkCredential]::new('', $s).Password } catch {}
    }
    return $null
}

function Get-Cache {
    if (Test-Path $Script:CacheFile) {
        try {
            $o = Get-Content $Script:CacheFile -Raw | ConvertFrom-Json
            $h = @{}; $o.PSObject.Properties | ForEach-Object { $h[$_.Name] = $_.Value }; return $h
        } catch {}
    }
    return @{}
}

function Get-VTReport($hash, $key) {
    for ($try = 0; $try -lt 3; $try++) {
        try {
            $r = Invoke-RestMethod -Uri "https://www.virustotal.com/api/v3/files/$hash" -Headers @{ 'x-apikey' = $key } -ErrorAction Stop
            $s = $r.data.attributes.last_analysis_stats
            $total = [int]$s.malicious + [int]$s.suspicious + [int]$s.harmless + [int]$s.undetected
            return [pscustomobject]@{ Status='Found'; Malicious=[int]$s.malicious; Suspicious=[int]$s.suspicious; Total=$total }
        } catch {
            $code = 0; if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
            if ($code -eq 404) { return [pscustomobject]@{ Status='Unknown'; Malicious=0; Suspicious=0; Total=0 } }
            if ($code -eq 429) { Log 'Rate limited, waiting 60s...' 'warn'; Wait-UI 60; if ($Script:Cancel) { return $null }; continue }
            if ($code -in 401,403) { Log 'VirusTotal rejected the API key.' 'bad'; return $false }
            return [pscustomobject]@{ Status="Error $code"; Malicious=0; Suspicious=0; Total=0 }
        }
    }
    return [pscustomobject]@{ Status='RateLimited'; Malicious=0; Suspicious=0; Total=0 }
}

function Test-TrustedMicrosoft($path) {
    try { $sig = Get-AuthenticodeSignature -FilePath $path -ErrorAction Stop
          return ($sig.Status -eq 'Valid' -and $sig.SignerCertificate.Subject -match 'Microsoft') } catch { return $false }
}

function Get-SystemTargets {
    $paths = New-Object System.Collections.Generic.HashSet[string] ([StringComparer]::OrdinalIgnoreCase)
    Get-Process -ErrorAction SilentlyContinue | ForEach-Object { try { if ($_.Path) { [void]$paths.Add($_.Path) } } catch {} }
    foreach ($k in 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run','HKLM:\Software\Microsoft\Windows\CurrentVersion\Run') {
        if (Test-Path $k) {
            (Get-ItemProperty $k).PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' } | ForEach-Object {
                $m = [regex]::Match([string]$_.Value, '^"?([^"]+?\.exe)')
                if ($m.Success -and (Test-Path $m.Groups[1].Value)) { [void]$paths.Add($m.Groups[1].Value) }
            }
        }
    }
    foreach ($d in "$env:USERPROFILE\Downloads","$env:APPDATA","$env:LOCALAPPDATA\Temp") {
        if (Test-Path $d) {
            Get-ChildItem $d -Include *.exe,*.dll,*.scr,*.bat,*.ps1 -Recurse -File -Depth 2 -ErrorAction SilentlyContinue |
                ForEach-Object { [void]$paths.Add($_.FullName) }
        }
    }
    return @($paths)
}

function Invoke-VTScan($targets) {
    $key = Get-VTKey
    if (-not $key) { Log 'Paste your VirusTotal API key above and press "Save key" first.' 'bad'; return }
    $targets = @($targets | Where-Object { $_ })
    if (-not $targets.Count) { Log 'Nothing to scan.' 'warn'; return }

    Set-Busy $true; $Script:Cancel = $false
    $UI.Results.Items.Clear(); $UI.Prog.Maximum = $targets.Count; $UI.Prog.Value = 0
    $cache = Get-Cache; $premium = [bool]$UI.ChkPremium.IsChecked
    $bad = 0; $sus = 0; $unk = 0; $i = 0
    Log "Scanning $($targets.Count) files..."

    foreach ($p in $targets) {
        if ($Script:Cancel) { Log 'Scan cancelled.' 'warn'; break }
        $i++; $UI.Prog.Value = $i; Pump
        Set-Status ("Checking {0}/{1}: {2}" -f $i, $targets.Count, (Split-Path $p -Leaf))
        if (Test-TrustedMicrosoft $p) { continue }
        try { $hash = (Get-FileHash -Path $p -Algorithm SHA256 -ErrorAction Stop).Hash } catch { continue }

        $rep = $null; $fromCache = $false
        if ($cache.ContainsKey($hash) -and $cache[$hash].Status -eq 'Found') { $rep = $cache[$hash]; $fromCache = $true }
        else {
            $rep = Get-VTReport $hash $key
            if ($rep -eq $false) { break }
            if ($null -eq $rep) { break }
            $cache[$hash] = $rep
            $cache | ConvertTo-Json -Depth 4 | Set-Content $Script:CacheFile
        }

        $verdict = if ($rep.Status -eq 'Unknown') { 'Unknown' }
                   elseif ($rep.Malicious -ge 3) { 'Malicious' }
                   elseif ($rep.Malicious -ge 1 -or $rep.Suspicious -ge 1) { 'Suspicious' }
                   elseif ($rep.Status -eq 'Found') { 'Clean' } else { $rep.Status }
        switch ($verdict) { 'Malicious' {$bad++} 'Suspicious' {$sus++} 'Unknown' {$unk++} }

        $row = [pscustomobject]@{
            Verdict = $verdict
            Flagged = if ($rep.Total) { "$($rep.Malicious) / $($rep.Total)" } else { '-' }
            Name    = Split-Path $p -Leaf
            File    = $p
            SHA256  = $hash
        }
        # worst first: insert bad ones at the top
        if ($verdict -in 'Malicious','Suspicious') { $UI.Results.Items.Insert(0, $row) } else { [void]$UI.Results.Items.Add($row) }
        $UI.ScanSummary.Text = "Malicious: $bad   Suspicious: $sus   Unknown: $unk"

        if (-not $fromCache -and -not $premium) { Set-Status 'Waiting (free API limit: 4 lookups/min)...'; Wait-UI 16 }
    }

    if ($bad -eq 0 -and $sus -eq 0) { Log 'Scan finished. Nothing flagged.' 'ok' }
    else { Log "Scan finished. $bad malicious, $sus suspicious. 1-2 detections are often false positives - use 'Open on VirusTotal' to check." 'warn' }
    Set-Status 'Ready'; Set-Busy $false; $UI.Prog.Value = 0
}

# ================================================================== Optimizer
function New-Backup {
    Log 'Creating restore point...'
    try {
        Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore' 'SystemRestorePointCreationFrequency' 0 | Out-Null
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description 'PCTool before optimize' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        Log 'Restore point created.' 'ok'
    } catch { Log "Restore point failed: $($_.Exception.Message)" 'warn' }
}

function Optimize-Power {
    $out = powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>&1
    $m = [regex]::Match("$out", '[0-9a-fA-F-]{36}')
    if ($m.Success) { powercfg -setactive $m.Value; Log 'Ultimate Performance power plan active.' 'ok' }
    else { powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e27be5e18c; Log 'High Performance power plan active.' 'ok' }
}
function Optimize-Gaming {
    Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode' 1 | Out-Null
    Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' 1 | Out-Null
    Set-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0 | Out-Null
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0 | Out-Null
    Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' 2 | Out-Null
    $g = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'
    Set-Reg $g 'GPU Priority' 8 | Out-Null; Set-Reg $g 'Priority' 6 | Out-Null
    Set-Reg $g 'Scheduling Category' 'High' 'String' | Out-Null
    Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' 'SystemResponsiveness' 10 | Out-Null
    Log 'Gaming tweaks applied (GPU scheduling needs a reboot).' 'ok'
}
function Optimize-Visuals {
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' 'VisualFXSetting' 2 | Out-Null
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency' 0 | Out-Null
    Set-Reg 'HKCU:\Control Panel\Desktop\WindowMetrics' 'MinAnimate' '0' 'String' | Out-Null
    Log 'Transparency and animations off (sign out/in to apply).' 'ok'
}
function Optimize-Mouse {
    Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseSpeed' '0' 'String' | Out-Null
    Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseThreshold1' '0' 'String' | Out-Null
    Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseThreshold2' '0' 'String' | Out-Null
    Log 'Mouse acceleration off.' 'ok'
}
function Optimize-Dns { ipconfig /flushdns | Out-Null; Log 'DNS cache flushed.' 'ok' }
function Clear-Junk {
    $drv = $env:SystemDrive.TrimEnd(':')
    $before = (Get-PSDrive -Name $drv).Free
    foreach ($d in $env:TEMP, "$env:SystemRoot\Temp", "$env:LOCALAPPDATA\Microsoft\Windows\INetCache", "$env:LOCALAPPDATA\D3DSCache") {
        if (Test-Path $d) { Get-ChildItem $d -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue; Pump }
    }
    try { Clear-RecycleBin -Force -ErrorAction SilentlyContinue } catch {}
    $after = (Get-PSDrive -Name $drv).Free
    Log ("Cleaned temp/cache, freed {0:N0} MB." -f (($after - $before)/1MB)) 'ok'
}

Step 82 'Building optimizer...'
$Script:Tweaks = @(
    @{ id='restore'; fn={ New-Backup };        title='Create a restore point first';  desc='Lets you roll back everything below from Windows System Restore.'; on=$true }
    @{ id='power';   fn={ Optimize-Power };    title='Ultimate Performance power plan'; desc='Stops the CPU from throttling down. Uses more power on laptops.'; on=$true }
    @{ id='game';    fn={ Optimize-Gaming };   title='Gaming tweaks';                 desc='Game Mode on, Game DVR off, GPU scheduling on, higher game priority.'; on=$true }
    @{ id='vis';     fn={ Optimize-Visuals };  title='Visual effects off';            desc='Turns off transparency and window animations. Snappier desktop.'; on=$true }
    @{ id='mouse';   fn={ Optimize-Mouse };    title='Mouse acceleration off';        desc='1:1 mouse movement, better aim consistency in shooters.'; on=$true }
    @{ id='dns';     fn={ Optimize-Dns };      title='Flush DNS cache';               desc='Clears stale network lookups.'; on=$true }
    @{ id='clean';   fn={ Clear-Junk };        title='Clean temp and cache files';    desc='Deletes temp files, shader cache and recycle bin contents.'; on=$true }
)
$Script:TweakBoxes = @{}
foreach ($t in $Script:Tweaks) {
    $card = [Windows.Controls.Border]::new()
    $card.Background = Brush '#1B1F2B'; $card.CornerRadius = [Windows.CornerRadius]::new(10)
    $card.Padding = [Windows.Thickness]::new(16,12,16,12); $card.Margin = [Windows.Thickness]::new(0,0,0,8)
    $sp = [Windows.Controls.StackPanel]::new()
    $cb = [Windows.Controls.CheckBox]::new(); $cb.Content = $t.title; $cb.IsChecked = $t.on; $cb.FontWeight = 'SemiBold'
    $tb = [Windows.Controls.TextBlock]::new(); $tb.Text = $t.desc; $tb.Foreground = Brush '#8A90A2'
    $tb.Margin = [Windows.Thickness]::new(24,4,0,0); $tb.TextWrapping = 'Wrap'; $tb.FontSize = 12
    [void]$sp.Children.Add($cb); [void]$sp.Children.Add($tb); $card.Child = $sp
    [void]$UI.TweakPanel.Children.Add($card)
    $Script:TweakBoxes[$t.id] = $cb
}

function Invoke-ApplyTweaks {
    Set-Busy $true
    try {
        foreach ($t in $Script:Tweaks) {
            if ($Script:TweakBoxes[$t.id].IsChecked) { Set-Status $t.title; & $t.fn; Pump }
        }
        Log 'All done. Reboot to fully apply everything.' 'ok'
    } catch { Log $_.Exception.Message 'bad' }
    Set-Status 'Ready'; Set-Busy $false
}

# ================================================================== Startup manager
function Load-Startup {
    $UI.StartPanel.Children.Clear()
    $found = 0
    foreach ($k in 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run','HKLM:\Software\Microsoft\Windows\CurrentVersion\Run') {
        if (-not (Test-Path $k)) { continue }
        (Get-ItemProperty $k).PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' } | ForEach-Object {
            $found++
            $cb = [Windows.Controls.CheckBox]::new()
            $cb.Content = "$($_.Name)   -   $($_.Value)"; $cb.Margin = [Windows.Thickness]::new(0,0,0,10)
            $cb.Tag = [pscustomobject]@{ Key=$k; Name=$_.Name; Value=$_.Value }
            [void]$UI.StartPanel.Children.Add($cb)
        }
    }
    if (-not $found) {
        $tb = [Windows.Controls.TextBlock]::new(); $tb.Text = 'No startup entries found in the registry.'; $tb.Foreground = Brush '#8A90A2'
        [void]$UI.StartPanel.Children.Add($tb)
    }
}

function Remove-StartupSelected {
    $sel = @($UI.StartPanel.Children | Where-Object { $_ -is [Windows.Controls.CheckBox] -and $_.IsChecked } | ForEach-Object { $_.Tag })
    if (-not $sel.Count) { Log 'Nothing selected.' 'warn'; return }
    $sel | ConvertTo-Json | Set-Content (Join-Path $Script:Dir ("startup-backup-{0:yyyyMMdd-HHmmss}.json" -f (Get-Date)))
    foreach ($it in $sel) {
        Remove-ItemProperty -Path $it.Key -Name $it.Name -ErrorAction SilentlyContinue
        Log "Removed from startup: $($it.Name)" 'ok'
    }
    Log "Backup saved in $Script:Dir" 'info'
    Load-Startup
}

Step 92 'Wiring up buttons...'
# ================================================================== Wire up events
$UI.TitleBar.Add_MouseLeftButtonDown({ try { $win.DragMove() } catch {} })
$UI.BtnMin.Add_Click({ $win.WindowState = 'Minimized' })
$UI.BtnClose.Add_Click({ $Script:Cancel = $true; $win.Close() })
$win.Add_Closing({ $Script:Cancel = $true })

$UI.NavDash.Add_Click({ Show-Page 'Dash' })
$UI.NavScan.Add_Click({ Show-Page 'Scan' })
$UI.NavOpt.Add_Click({ Show-Page 'Opt' })
$UI.NavStart.Add_Click({ Show-Page 'Start' })

$UI.BtnRefresh.Add_Click({ Update-Dashboard })
$UI.BtnDefender.Add_Click({ Invoke-DefenderScan })

$UI.BtnSaveKey.Add_Click({
    if ($UI.KeyBox.SecurePassword.Length -gt 0) {
        $UI.KeyBox.SecurePassword | ConvertFrom-SecureString | Set-Content $Script:KeyFile
        $UI.KeyBox.Clear(); Log 'API key saved (encrypted for your Windows account).' 'ok'
    } else { Log 'Paste your key first. Get one free at virustotal.com/gui/my-apikey' 'warn' }
})
$UI.BtnScanSys.Add_Click({ Log 'Collecting running programs, startup items and Downloads/AppData/Temp files...'; Invoke-VTScan (Get-SystemTargets) })
$UI.BtnScanFile.Add_Click({
    $d = [Windows.Forms.OpenFileDialog]::new()
    if ($d.ShowDialog() -eq 'OK') { Invoke-VTScan @($d.FileName) }
})
$UI.BtnScanFolder.Add_Click({
    $d = [Windows.Forms.FolderBrowserDialog]::new()
    if ($d.ShowDialog() -eq 'OK') { Invoke-VTScan (Get-ChildItem $d.SelectedPath -Recurse -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName) }
})
$UI.BtnCancel.Add_Click({ $Script:Cancel = $true })
$UI.BtnOpenVT.Add_Click({
    $r = $UI.Results.SelectedItem
    if ($r) { Start-Process "https://www.virustotal.com/gui/file/$($r.SHA256)" } else { Log 'Select a row first.' 'warn' }
})

$UI.BtnApply.Add_Click({ Invoke-ApplyTweaks })
$UI.BtnAll.Add_Click({ $Script:TweakBoxes.Values | ForEach-Object { $_.IsChecked = $true } })
$UI.BtnNone.Add_Click({ $Script:TweakBoxes.Values | ForEach-Object { $_.IsChecked = $false } })
$UI.BtnDisableStart.Add_Click({ Remove-StartupSelected })
$UI.BtnReloadStart.Add_Click({ Load-Startup })

$win.Add_ContentRendered({
    Show-Page 'Dash'
    Log 'Welcome to PCTool.' 'ok'
    if (Get-VTKey) { Log 'VirusTotal key found.' 'info' } else { Log 'No VirusTotal key yet - add one in Virus Scanner.' 'warn' }
    Update-Dashboard
})

Step 100 'Done - opening window'
Write-Host ''
Write-Host '  PCTool is running. Keep this console open: activity and errors show here.' -ForegroundColor Green
Write-Host ''
$ErrorActionPreference = 'Continue'   # once running, one failed action shouldn't kill the app
[void]$win.ShowDialog()
Write-Host '  PCTool window closed.' -ForegroundColor Gray
}
catch {
    Write-Host ''
    Write-Host '  [ERROR] PCTool failed to load:' -ForegroundColor Red
    Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
    if ($_.InvocationInfo) {
        Write-Host ("  at line {0}: {1}" -f $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.Line.Trim()) -ForegroundColor DarkRed
    }
    Write-Host ''
    Write-Host '  Copy the red text above and send it to get it fixed.' -ForegroundColor Yellow
}
