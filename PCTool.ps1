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
            <Button x:Name="NavTools" Style="{StaticResource BtnNav}" Content="🎮   Game Tools"/>
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
              <Button x:Name="BtnAll" Style="{StaticResource BtnGhost}" Content="Recommended"/>
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

          <!-- Game tools -->
          <ScrollViewer x:Name="PgTools" Visibility="Collapsed" VerticalScrollBarVisibility="Auto">
            <StackPanel>
              <TextBlock Text="Game Tools" FontSize="28" FontWeight="Bold" Foreground="White"/>
              <TextBlock Text="Per-game tweaks, plus the steps that have to be done in a driver menu or the BIOS." Foreground="#8A90A2" Margin="0,2,0,6"/>
              <StackPanel x:Name="ToolsPanel"/>
            </StackPanel>
          </ScrollViewer>
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
               'NavTools','PgTools','ToolsPanel','StartPanel','BtnDisableStart','BtnReloadStart','Log','Status','AdminTag') {
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
    $map = @{ Dash=@('PgDash','NavDash'); Scan=@('PgScan','NavScan'); Opt=@('PgOpt','NavOpt'); Start=@('PgStart','NavStart'); Tools=@('PgTools','NavTools') }
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

function Set-DXFlag($key, $val) {
    $path = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
    $cur = ''
    try { $cur = [string](Get-Item $path -ErrorAction Stop).GetValue('DirectXUserGlobalSettings') } catch {}
    $d = [ordered]@{}
    foreach ($part in ($cur -split ';')) { if ($part -match '^(.+?)=(.*)$') { $d[$Matches[1]] = $Matches[2] } }
    $d[$key] = $val
    $new = (($d.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ';') + ';'
    Set-Reg $path 'DirectXUserGlobalSettings' $new 'String' | Out-Null
}

function Set-NicProp([string]$pattern, [string[]]$values) {
    $n = 0
    $adapters = @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' })
    foreach ($a in $adapters) {
        $props = @(Get-NetAdapterAdvancedProperty -Name $a.Name -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match $pattern })
        foreach ($pr in $props) {
            foreach ($v in $values) {
                try { Set-NetAdapterAdvancedProperty -Name $a.Name -DisplayName $pr.DisplayName -DisplayValue $v -ErrorAction Stop; $n++; break } catch {}
            }
        }
    }
    return $n
}

# ---- Windows and gaming features
function Opt-GameMode {
    Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode' 1 | Out-Null
    Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' 1 | Out-Null
    Log 'Game Mode enabled.' 'ok'
}
function Opt-Hags {
    Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' 2 | Out-Null
    Log 'Hardware GPU scheduling on (reboot needed, needs a recent GPU and driver).' 'ok'
}
function Opt-GameBar {
    Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'UseNexusForGameBarEnabled' 0 | Out-Null
    Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'ShowStartupPanel' 0 | Out-Null
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0 | Out-Null
    Log 'Xbox Game Bar overlay off.' 'ok'
}
function Opt-Captures {
    Set-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0 | Out-Null
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0 | Out-Null
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'HistoricalCaptureEnabled' 0 | Out-Null
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' 'AllowGameDVR' 0 | Out-Null
    Log 'Background game recording (Game DVR) off.' 'ok'
}
function Opt-Vrr {
    Set-DXFlag 'VRROptimizeEnable' '1'
    Log 'Windows VRR option on. Also enable G-Sync/FreeSync in your GPU driver and monitor menu.' 'ok'
}
function Opt-Windowed {
    Set-DXFlag 'SwapEffectUpgradeEnable' '1'
    Log 'Optimizations for windowed games on. (Auto HDR itself is a Windows 11 setting - see Game Tools.)' 'ok'
}
function Opt-Power {
    $out = powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>&1
    $m = [regex]::Match("$out", '[0-9a-fA-F-]{36}')
    if ($m.Success) { powercfg -setactive $m.Value; Log 'Ultimate Performance power plan active.' 'ok' }
    else { powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e27be5e18c; Log 'High Performance power plan active.' 'ok' }
}
function Opt-Sched {
    $g = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'
    Set-Reg $g 'GPU Priority' 8 | Out-Null; Set-Reg $g 'Priority' 6 | Out-Null
    Set-Reg $g 'Scheduling Category' 'High' 'String' | Out-Null
    Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' 'SystemResponsiveness' 10 | Out-Null
    Log 'Games get higher CPU/GPU scheduling priority.' 'ok'
}
function Opt-Visuals {
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' 'VisualFXSetting' 2 | Out-Null
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency' 0 | Out-Null
    Set-Reg 'HKCU:\Control Panel\Desktop\WindowMetrics' 'MinAnimate' '0' 'String' | Out-Null
    Log 'Transparency and animations off (sign out/in to apply).' 'ok'
}
function Opt-Mouse {
    Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseSpeed' '0' 'String' | Out-Null
    Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseThreshold1' '0' 'String' | Out-Null
    Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseThreshold2' '0' 'String' | Out-Null
    Log 'Mouse acceleration off.' 'ok'
}
function Opt-MemIntegrity {
    Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' 'Enabled' 0 | Out-Null
    Log 'Memory Integrity off (reboot needed). Your PC is less protected against kernel-level malware now.' 'warn'
}
function Opt-VMP {
    Log 'Turning off Virtual Machine Platform (can take a minute)...'
    try {
        $f = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -ErrorAction Stop
        if ($f.State -eq 'Disabled') { Log 'Virtual Machine Platform was already off.' 'ok'; return }
        [void](Disable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart -ErrorAction Stop)
        Log 'Virtual Machine Platform off (reboot needed).' 'ok'
    } catch { Log "Could not change Virtual Machine Platform: $($_.Exception.Message)" 'warn' }
}

# ---- Background and cleanup
function Opt-SysMain {
    $ssd = $true
    try {
        $pd = Get-Partition -DriveLetter ($env:SystemDrive.TrimEnd(':')) | Get-Disk | Get-PhysicalDisk
        if ($pd.MediaType -eq 'HDD') { $ssd = $false }
    } catch {}
    if (-not $ssd) { Log 'Skipped SysMain: Windows is on a hard drive, where SysMain actually helps.' 'warn'; return }
    Stop-Service SysMain -Force -ErrorAction SilentlyContinue
    Set-Service SysMain -StartupType Disabled -ErrorAction SilentlyContinue
    Log 'SysMain (Superfetch) off.' 'ok'
}
function Opt-Telemetry {
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' 0 | Out-Null
    foreach ($svc in 'DiagTrack','dmwappushservice') {
        Stop-Service $svc -Force -ErrorAction SilentlyContinue
        Set-Service $svc -StartupType Disabled -ErrorAction SilentlyContinue
    }
    Log 'Telemetry reduced and the diagnostics services are off.' 'ok'
}
function Opt-Storage {
    $k = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy'
    Set-Reg $k '01' 1 | Out-Null     # Storage Sense on
    Set-Reg $k '04' 1 | Out-Null     # delete temp files
    Set-Reg $k '08' 1 | Out-Null     # empty recycle bin
    Set-Reg $k '256' 30 | Out-Null   # ...items older than 30 days
    Set-Reg $k '2048' 7 | Out-Null   # run weekly
    Log 'Storage Sense on: weekly cleanup of temp files and old recycle bin items (Downloads untouched).' 'ok'
}
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

# ---- Network
function Opt-Dns { ipconfig /flushdns | Out-Null; Log 'DNS cache flushed.' 'ok' }
function Opt-EEE {
    $n = Set-NicProp 'Energy[- ]?Efficient|Green Ethernet|^EEE$|Advanced EEE' @('Disabled','Off')
    if ($n -gt 0) { Log "Energy Efficient Ethernet turned off on $n setting(s) (your connection may blink for a second)." 'ok' }
    else { Log 'No Energy Efficient Ethernet setting found on your active adapters (Wi-Fi and some NICs do not have one).' 'info' }
}
function Opt-IntMod {
    $n = Set-NicProp '^Interrupt Moderation$' @('Disabled','Off')
    if ($n -gt 0) { Log 'Interrupt Moderation turned off (slightly higher CPU use, lower network latency).' 'ok' }
    else { Log 'No Interrupt Moderation setting found on your active adapters.' 'info' }
}

# ---- Per-game tools
function Pick-Exe {
    $d = [Windows.Forms.OpenFileDialog]::new()
    $d.Filter = 'Programs (*.exe)|*.exe'; $d.Title = 'Pick the game .exe'
    if ($d.ShowDialog() -eq 'OK') { return $d.FileName }
    return $null
}
function Set-GamePriority($exe, [bool]$remove) {
    $name = Split-Path $exe -Leaf
    $key = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$name\PerfOptions"
    if ($remove) { Remove-Item $key -ErrorAction SilentlyContinue; Log "High priority removed for $name." 'ok' }
    else { Set-Reg $key 'CpuPriorityClass' 3 | Out-Null; Log "$name will now always start with High CPU priority." 'ok' }
}
function Set-FSO($exe, [bool]$undo) {
    $p = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
    $flag = 'DISABLEDXMAXIMIZEDWINDOWEDMODE'
    $cur = ''
    try { $cur = [string](Get-Item $p -ErrorAction Stop).GetValue($exe) } catch {}
    $tokens = @($cur -split '\s+' | Where-Object { $_ -and $_ -ne '~' -and $_ -ne $flag })
    if (-not $undo) { $tokens += $flag }
    if ($tokens.Count -gt 0) { Set-Reg $p $exe ('~ ' + ($tokens -join ' ')) 'String' | Out-Null }
    else { Remove-ItemProperty -Path $p -Name $exe -ErrorAction SilentlyContinue }
    $leaf = Split-Path $exe -Leaf
    if ($undo) { Log "Fullscreen optimizations restored for $leaf." 'ok' } else { Log "Fullscreen optimizations disabled for $leaf." 'ok' }
}
function Check-Ram {
    $m = @(Get-CimInstance Win32_PhysicalMemory)
    if (-not $m.Count) { Log 'Could not read RAM info.' 'warn'; return }
    $cur = ($m | Measure-Object ConfiguredClockSpeed -Maximum).Maximum
    $rated = ($m | Measure-Object Speed -Maximum).Maximum
    Log "RAM is running at $cur MHz (modules report $rated MHz)." 'info'
    Log 'Compare this with the speed printed on your RAM sticker/box (e.g. DDR4-3600, DDR5-6000). If yours is lower, XMP/EXPO is off - enable it in the BIOS.' 'warn'
}

# ---- UI builders shared by Optimizer and Game Tools
function Add-Header($panel, $text) {
    $t = [Windows.Controls.TextBlock]::new(); $t.Text = $text
    $t.FontSize = 16; $t.FontWeight = 'SemiBold'; $t.Foreground = Brush '#7C5CFF'
    $t.Margin = [Windows.Thickness]::new(0,14,0,8)
    [void]$panel.Children.Add($t)
}

Step 82 'Building optimizer...'
$Script:Tweaks = @(
    @{ id='restore';  group='Safety';                  fn={ New-Backup };      on=$true;  caution=$false; title='Create a restore point first';
       desc='Lets you roll back everything below from Windows System Restore.' }

    @{ id='gamemode'; group='Windows and gaming';      fn={ Opt-GameMode };    on=$true;  caution=$false; title='Enable Game Mode';
       desc='Windows prioritizes your active game over background work.' }
    @{ id='hags';     group='Windows and gaming';      fn={ Opt-Hags };        on=$true;  caution=$false; title='Hardware-accelerated GPU scheduling (HAGS)';
       desc='The GPU manages its own memory scheduling. Lower latency on most modern cards. Needs a reboot.' }
    @{ id='gamebar';  group='Windows and gaming';      fn={ Opt-GameBar };     on=$true;  caution=$false; title='Turn off Xbox Game Bar';
       desc='Removes the overlay that can cause micro-stutters.' }
    @{ id='capture';  group='Windows and gaming';      fn={ Opt-Captures };    on=$true;  caution=$false; title='Disable background recording / captures';
       desc='Stops Windows recording gameplay in the background.' }
    @{ id='vrr';      group='Windows and gaming';      fn={ Opt-Vrr };         on=$true;  caution=$false; title='Variable refresh rate (VRR) for windowed games';
       desc='Turns on the Windows VRR option. You still need G-Sync/FreeSync enabled in the driver and monitor.' }
    @{ id='windowed'; group='Windows and gaming';      fn={ Opt-Windowed };    on=$true;  caution=$false; title='Optimizations for windowed games';
       desc='Lets borderless/windowed games use the faster flip presentation model.' }
    @{ id='power';    group='Windows and gaming';      fn={ Opt-Power };       on=$true;  caution=$false; title='Ultimate Performance power plan';
       desc='Stops the CPU throttling down. Uses more power on laptops.' }
    @{ id='sched';    group='Windows and gaming';      fn={ Opt-Sched };       on=$true;  caution=$false; title='Higher CPU/GPU priority for games';
       desc='Raises scheduling priority for the Games task profile.' }
    @{ id='visuals';  group='Windows and gaming';      fn={ Opt-Visuals };     on=$true;  caution=$false; title='Turn off transparency and visual effects';
       desc='Removes Windows animations and blur. Snappier desktop.' }
    @{ id='mouse';    group='Windows and gaming';      fn={ Opt-Mouse };       on=$true;  caution=$false; title='Mouse acceleration off';
       desc='1:1 mouse movement, more consistent aim in shooters.' }
    @{ id='memint';   group='Windows and gaming';      fn={ Opt-MemIntegrity };on=$false; caution=$true;  title='Disable Memory Integrity (Core Isolation)';
       desc='Can give a few percent more FPS on some CPUs, but lowers protection against kernel-level malware. Reboot needed.' }
    @{ id='vmp';      group='Windows and gaming';      fn={ Opt-VMP };         on=$false; caution=$true;  title='Turn off Virtual Machine Platform';
       desc='Only if you do not use WSL2, Docker, Windows Sandbox, Android apps or emulators that need it. Reboot needed.' }

    @{ id='sysmain';  group='Background and cleanup';  fn={ Opt-SysMain };     on=$false; caution=$true;  title='Disable SysMain (Superfetch)';
       desc='Helps on some SSD systems. Skipped automatically if Windows is on a hard drive.' }
    @{ id='telem';    group='Background and cleanup';  fn={ Opt-Telemetry };   on=$false; caution=$true;  title='Reduce Windows telemetry';
       desc='Turns off the diagnostics services. Windows may still send basic data on Home/Pro.' }
    @{ id='storage';  group='Background and cleanup';  fn={ Opt-Storage };     on=$true;  caution=$false; title='Turn on Storage Sense';
       desc='Weekly automatic cleanup of temp files and old recycle bin items. Does not touch Downloads.' }
    @{ id='clean';    group='Background and cleanup';  fn={ Clear-Junk };      on=$true;  caution=$false; title='Clean temp and cache files now';
       desc='Deletes temp files, shader cache leftovers and the recycle bin.' }

    @{ id='dns';      group='Network';                 fn={ Opt-Dns };         on=$true;  caution=$false; title='Flush DNS cache';
       desc='Clears stale network lookups.' }
    @{ id='eee';      group='Network';                 fn={ Opt-EEE };         on=$true;  caution=$false; title='Disable Energy Efficient Ethernet';
       desc='Stops the network card sleeping between packets. Your connection may blink briefly.' }
    @{ id='intmod';   group='Network';                 fn={ Opt-IntMod };      on=$false; caution=$true;  title='Disable Interrupt Moderation';
       desc='Lower network latency but higher CPU use. Test it, not everyone benefits.' }
)
$Script:TweakBoxes = @{}
$lastGroup = ''
foreach ($t in $Script:Tweaks) {
    if ($t.group -ne $lastGroup) { Add-Header $UI.TweakPanel $t.group; $lastGroup = $t.group }
    $card = [Windows.Controls.Border]::new()
    $card.Background = Brush '#1B1F2B'; $card.CornerRadius = [Windows.CornerRadius]::new(10)
    $card.Padding = [Windows.Thickness]::new(16,12,16,12); $card.Margin = [Windows.Thickness]::new(0,0,0,8)
    $sp = [Windows.Controls.StackPanel]::new()
    $row = [Windows.Controls.StackPanel]::new(); $row.Orientation = 'Horizontal'
    $cb = [Windows.Controls.CheckBox]::new(); $cb.Content = $t.title; $cb.IsChecked = $t.on; $cb.FontWeight = 'SemiBold'
    [void]$row.Children.Add($cb)
    if ($t.caution) {
        $tag = [Windows.Controls.TextBlock]::new(); $tag.Text = '   ADVANCED - read first'
        $tag.Foreground = Brush '#F5B83D'; $tag.FontSize = 11; $tag.VerticalAlignment = 'Center'
        [void]$row.Children.Add($tag)
    }
    $tb = [Windows.Controls.TextBlock]::new(); $tb.Text = $t.desc; $tb.Foreground = Brush '#8A90A2'
    $tb.Margin = [Windows.Thickness]::new(24,4,0,0); $tb.TextWrapping = 'Wrap'; $tb.FontSize = 12
    [void]$sp.Children.Add($row); [void]$sp.Children.Add($tb); $card.Child = $sp
    [void]$UI.TweakPanel.Children.Add($card)
    $Script:TweakBoxes[$t.id] = $cb
}

# ---- Game Tools page
function Add-Card($panel, $title, $text, $links) {
    $card = [Windows.Controls.Border]::new()
    $card.Background = Brush '#1B1F2B'; $card.CornerRadius = [Windows.CornerRadius]::new(10)
    $card.Padding = [Windows.Thickness]::new(16,12,16,12); $card.Margin = [Windows.Thickness]::new(0,0,0,8)
    $sp = [Windows.Controls.StackPanel]::new()
    $h = [Windows.Controls.TextBlock]::new(); $h.Text = $title; $h.FontWeight = 'SemiBold'; $h.Foreground = Brush '#FFFFFF'; $h.FontSize = 14
    $b = [Windows.Controls.TextBlock]::new(); $b.Text = $text; $b.Foreground = Brush '#8A90A2'; $b.TextWrapping = 'Wrap'
    $b.FontSize = 12; $b.Margin = [Windows.Thickness]::new(0,4,0,0)
    [void]$sp.Children.Add($h); [void]$sp.Children.Add($b)
    foreach ($l in @($links)) {
        if (-not $l) { continue }
        $btn = [Windows.Controls.Button]::new(); $btn.Content = $l.t; $btn.Style = $win.FindResource('BtnGhost')
        $btn.HorizontalAlignment = 'Left'; $btn.Margin = [Windows.Thickness]::new(0,8,0,0); $btn.Padding = [Windows.Thickness]::new(12,6,12,6)
        $u = $l.u
        $sb = { Start-Process $u }.GetNewClosure()
        $btn.Add_Click($sb)
        [void]$sp.Children.Add($btn)
    }
    $card.Child = $sp; [void]$panel.Children.Add($card)
}
function Add-ToolButtons($panel, $defs) {
    $wp = [Windows.Controls.WrapPanel]::new()
    foreach ($d in $defs) {
        $btn = [Windows.Controls.Button]::new(); $btn.Content = $d.t; $btn.Style = $win.FindResource('BtnGhost')
        $btn.Margin = [Windows.Thickness]::new(0,0,10,10)
        $btn.Add_Click($d.a)
        [void]$wp.Children.Add($btn)
    }
    [void]$panel.Children.Add($wp)
}

Add-Header $UI.ToolsPanel 'Per-game tools (you pick the game .exe)'
Add-ToolButtons $UI.ToolsPanel @(
    @{ t='High CPU priority for a game...';        a={ $e = Pick-Exe; if ($e) { Set-GamePriority $e $false } } }
    @{ t='Disable fullscreen optimizations...';    a={ $e = Pick-Exe; if ($e) { Set-FSO $e $false } } }
    @{ t='Undo both for a game...';                a={ $e = Pick-Exe; if ($e) { Set-GamePriority $e $true; Set-FSO $e $true } } }
    @{ t='Check my RAM speed (XMP/EXPO)';          a={ Check-Ram } }
    @{ t='Open Startup Apps';                      a={ Show-Page 'Start' } }
)
Add-Card $UI.ToolsPanel 'Heads up on game priority' 'Setting High priority sticks across launches. Skip it for games with strict anti-cheat (Vanguard, FACEIT, etc.) in case it gets flagged. Gains are usually small.' @()

Add-Header $UI.ToolsPanel 'Graphics drivers (manual, needs their own tools)'
Add-Card $UI.ToolsPanel '1. Clean driver install with DDU' 'Download the latest driver first. Boot into Safe Mode, run Display Driver Uninstaller to wipe the old driver, reboot, then install the new one. Fixes weird stutter after driver swaps.' @(@{ t='Get DDU (Wagnard)'; u='https://www.wagnardsoft.com/' })
Add-Card $UI.ToolsPanel '2. Slim driver install (NVCleanstall / AMD)' 'NVCleanstall lets you install the NVIDIA driver without telemetry and extras. AMD users can choose "Driver only" in the installer.' @(@{ t='Get NVCleanstall (TechPowerUp)'; u='https://www.techpowerup.com/' })
Add-Card $UI.ToolsPanel '3. Power management: prefer maximum performance' 'NVIDIA: Control Panel > Manage 3D settings > Power management mode > Prefer maximum performance. AMD: Adrenalin > Gaming > Graphics, use the default or Performance profile. Keeps the GPU from downclocking mid-game.' @()
Add-Card $UI.ToolsPanel '4. Texture filtering quality' 'NVIDIA: Control Panel > Manage 3D settings > Texture filtering - Quality > High performance. A small FPS gain for a barely visible quality loss.' @()
Add-Card $UI.ToolsPanel '5. Shader cache size' 'NVIDIA: Control Panel > Manage 3D settings > Shader Cache Size > 10 GB or higher (put it on an SSD). AMD: Adrenalin > Graphics > Advanced > Shader Cache > AMD Optimized. Reduces stutter when new areas load.' @()
Add-Card $UI.ToolsPanel '6. Low Latency Mode / NVIDIA Reflex' 'Use Reflex (On, or On + Boost) in games that support it for lower input lag. For non-competitive games where you want max FPS, set Low Latency Mode to Off. Do not stack the driver setting on top of in-game Reflex.' @()
Add-Card $UI.ToolsPanel '7. Cap FPS just below your refresh rate' 'On a 144 Hz monitor cap at about 141 to 142 FPS (NVIDIA Control Panel > Max Frame Rate, or in-game, or RTSS). Keeps the GPU from pegging at 100% and avoids latency spikes.' @()
Add-Card $UI.ToolsPanel '8. G-Sync / FreeSync and Auto HDR' 'Turn on G-Sync/FreeSync in your GPU driver and in the monitor menu. Auto HDR is Windows 11 only: Settings > System > Display > HDR. This PC may be on Windows 10, where Auto HDR is not available.' @()

Add-Header $UI.ToolsPanel 'Apps and BIOS (manual)'
Add-Card $UI.ToolsPanel '9. Uninstall unused apps properly' 'Revo Uninstaller removes leftover registry keys and files that normal uninstalls leave behind.' @(@{ t='Get Revo Uninstaller'; u='https://www.revouninstaller.com/' })
Add-Card $UI.ToolsPanel '10. Intelligent Standby List Cleaner (ISLC)' 'Community tool that clears the RAM standby list to reduce stutter in long sessions. Helps mostly on systems with 16 GB or less. Third-party tool, use at your own risk.' @(@{ t='Get ISLC (Wagnard)'; u='https://www.wagnardsoft.com/' })
Add-Card $UI.ToolsPanel '11. Enable XMP / EXPO in the BIOS' 'Restart, tap Del or F2 to enter the BIOS, find XMP (Intel) or EXPO/DOCP (AMD), enable profile 1, save and reboot. Without it your RAM runs at slow default speeds. Use the "Check my RAM speed" button above to see where you stand.' @()

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
$UI.NavTools.Add_Click({ Show-Page 'Tools' })

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
$UI.BtnAll.Add_Click({ foreach ($t in $Script:Tweaks) { $Script:TweakBoxes[$t.id].IsChecked = [bool]$t.on } })
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
