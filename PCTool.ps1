<#
 PCTool - PC Checker (VirusTotal hash lookup) + Windows/Gaming Optimizer
 Run from an ADMIN cmd:
   powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/YOURUSER/PCTool/main/PCTool.ps1 | iex"
#>

$ErrorActionPreference = 'Continue'
$Script:Dir = Join-Path $env:APPDATA 'PCTool'
New-Item -ItemType Directory -Force -Path $Script:Dir | Out-Null
$Script:CacheFile = Join-Path $Script:Dir 'vt-cache.json'

function Test-Admin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Write-Head($t) { Write-Host "`n=== $t ===" -ForegroundColor Cyan }
function Write-Ok($t)   { Write-Host "  [OK]   $t" -ForegroundColor Green }
function Write-Warn2($t){ Write-Host "  [WARN] $t" -ForegroundColor Yellow }
function Write-Bad($t)  { Write-Host "  [BAD]  $t" -ForegroundColor Red }

function Set-Reg($path, $name, $value, $type = 'DWord') {
    try {
        if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        New-ItemProperty -Path $path -Name $name -Value $value -PropertyType $type -Force | Out-Null
        return $true
    } catch { Write-Warn2 "Could not set $path\$name : $($_.Exception.Message)"; return $false }
}

# ---------------------------------------------------------------- VirusTotal
function Get-VTKey {
    $f = Join-Path $Script:Dir 'vt.key'
    if (Test-Path $f) {
        try {
            $s = Get-Content $f | ConvertTo-SecureString   # DPAPI: only decryptable by your Windows account
            return [Net.NetworkCredential]::new('', $s).Password
        } catch {}
    }
    Write-Host "Get a free API key at https://www.virustotal.com/gui/my-apikey" -ForegroundColor Gray
    $s = Read-Host 'Paste your VirusTotal API key' -AsSecureString
    $s | ConvertFrom-SecureString | Set-Content $f
    return [Net.NetworkCredential]::new('', $s).Password
}

function Get-Cache {
    if (Test-Path $Script:CacheFile) {
        try { return Get-Content $Script:CacheFile -Raw | ConvertFrom-Json -AsHashtable } catch {}
        try {
            $o = Get-Content $Script:CacheFile -Raw | ConvertFrom-Json
            $h = @{}; $o.PSObject.Properties | ForEach-Object { $h[$_.Name] = $_.Value }; return $h
        } catch {}
    }
    return @{}
}

function Get-VTReport($hash, $key) {
    # Hash lookup only - the file itself is never uploaded.
    for ($try = 0; $try -lt 3; $try++) {
        try {
            $r = Invoke-RestMethod -Uri "https://www.virustotal.com/api/v3/files/$hash" `
                 -Headers @{ 'x-apikey' = $key } -ErrorAction Stop
            $s = $r.data.attributes.last_analysis_stats
            return [pscustomobject]@{ Status='Found'; Malicious=[int]$s.malicious; Suspicious=[int]$s.suspicious; Harmless=[int]$s.harmless }
        } catch {
            $code = 0
            if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
            if ($code -eq 404) { return [pscustomobject]@{ Status='Unknown'; Malicious=0; Suspicious=0; Harmless=0 } }
            if ($code -eq 429) { Write-Host "    rate limited, waiting 60s..." -ForegroundColor DarkGray; Start-Sleep 60; continue }
            if ($code -eq 401 -or $code -eq 403) { Write-Bad "API key rejected. Delete $Script:Dir\vt.key and retry."; return $null }
            return [pscustomobject]@{ Status="Error($code)"; Malicious=0; Suspicious=0; Harmless=0 }
        }
    }
    return [pscustomobject]@{ Status='RateLimited'; Malicious=0; Suspicious=0; Harmless=0 }
}

function Test-TrustedMicrosoft($path) {
    try {
        $sig = Get-AuthenticodeSignature -FilePath $path -ErrorAction Stop
        return ($sig.Status -eq 'Valid' -and $sig.SignerCertificate.Subject -match 'Microsoft')
    } catch { return $false }
}

function Get-ScanTargets {
    $paths = New-Object System.Collections.Generic.HashSet[string] ([StringComparer]::OrdinalIgnoreCase)
    Get-Process -ErrorAction SilentlyContinue | ForEach-Object {
        try { if ($_.Path) { [void]$paths.Add($_.Path) } } catch {}
    }
    foreach ($k in 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run','HKLM:\Software\Microsoft\Windows\CurrentVersion\Run') {
        if (Test-Path $k) {
            (Get-ItemProperty $k).PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' } | ForEach-Object {
                $m = [regex]::Match([string]$_.Value, '^"?([^"]+?\.exe)')
                if ($m.Success -and (Test-Path $m.Groups[1].Value)) { [void]$paths.Add($m.Groups[1].Value) }
            }
        }
    }
    foreach ($d in "$env:USERPROFILE\Downloads", "$env:APPDATA", "$env:LOCALAPPDATA\Temp") {
        if (Test-Path $d) {
            Get-ChildItem $d -Include *.exe,*.dll,*.scr,*.bat,*.ps1 -Recurse -File -ErrorAction SilentlyContinue -Depth 2 |
                ForEach-Object { [void]$paths.Add($_.FullName) }
        }
    }
    return $paths
}

function Invoke-VTScan($customPath) {
    Write-Head 'VirusTotal scan'
    $key = Get-VTKey
    $cache = Get-Cache

    if ($customPath) {
        if (Test-Path $customPath -PathType Container) {
            $targets = Get-ChildItem $customPath -Recurse -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
        } else { $targets = @($customPath) }
    } else {
        Write-Host '  Collecting running programs, startup items, Downloads/AppData/Temp executables...'
        $targets = Get-ScanTargets
    }

    $results = @()
    $i = 0
    foreach ($p in $targets) {
        $i++
        if (Test-TrustedMicrosoft $p) { continue }
        try { $hash = (Get-FileHash -Path $p -Algorithm SHA256 -ErrorAction Stop).Hash } catch { continue }

        if ($cache.ContainsKey($hash) -and $cache[$hash].Status -eq 'Found') {
            $rep = $cache[$hash]
        } else {
            Write-Host ("  [{0}/{1}] checking {2}" -f $i, $targets.Count, (Split-Path $p -Leaf)) -ForegroundColor DarkGray
            $rep = Get-VTReport $hash $key
            if ($null -eq $rep) { return }
            $cache[$hash] = $rep
            $cache | ConvertTo-Json -Depth 4 | Set-Content $Script:CacheFile
            Start-Sleep -Seconds 16   # free tier = 4 lookups/minute
        }
        $results += [pscustomobject]@{ File=$p; SHA256=$hash; Status=$rep.Status; Malicious=$rep.Malicious; Suspicious=$rep.Suspicious }
    }

    Write-Head 'Results'
    $bad  = $results | Where-Object { $_.Malicious -ge 3 }
    $sus  = $results | Where-Object { $_.Malicious -in 1,2 -or $_.Suspicious -ge 1 } | Where-Object { $_ -notin $bad }
    $unk  = $results | Where-Object { $_.Status -eq 'Unknown' }
    foreach ($r in $bad) { Write-Bad  "$($r.File)  ($($r.Malicious) engines flag it)" }
    foreach ($r in $sus) { Write-Warn2 "$($r.File)  ($($r.Malicious) malicious / $($r.Suspicious) suspicious - often a false positive, check manually)" }
    foreach ($r in $unk) { Write-Host "  [?]    $($r.File)  (never seen by VirusTotal - not necessarily bad)" -ForegroundColor Gray }
    if (-not $bad -and -not $sus) { Write-Ok 'Nothing flagged.' }

    $report = Join-Path $Script:Dir ("scan-{0:yyyyMMdd-HHmmss}.csv" -f (Get-Date))
    $results | Export-Csv $report -NoTypeInformation
    Write-Host "`n  Full report saved: $report" -ForegroundColor Gray
    Write-Host "  Verify any hit at https://www.virustotal.com/gui/file/<SHA256>" -ForegroundColor Gray
}

# ---------------------------------------------------------------- System check
function Invoke-SystemCheck {
    Write-Head 'System check'
    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $gpu = Get-CimInstance Win32_VideoController | Select-Object -First 1
    Write-Host "  OS:   $($os.Caption) build $($os.BuildNumber)"
    Write-Host "  CPU:  $($cpu.Name)"
    Write-Host "  GPU:  $($gpu.Name)  (driver $($gpu.DriverVersion), $([datetime]$gpu.DriverDate | Get-Date -Format yyyy-MM-dd))"
    $ramGB = [math]::Round($os.TotalVisibleMemorySize/1MB,1); $freeGB = [math]::Round($os.FreePhysicalMemory/1MB,1)
    Write-Host "  RAM:  $freeGB GB free of $ramGB GB"
    $up = (Get-Date) - $os.LastBootUpTime
    if ($up.TotalDays -gt 7) { Write-Warn2 ("Uptime {0:N0} days - reboot occasionally" -f $up.TotalDays) } else { Write-Ok ("Uptime {0:N1} days" -f $up.TotalDays) }

    Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object {
        $pct = [math]::Round($_.FreeSpace / $_.Size * 100)
        $msg = "Drive $($_.DeviceID) $pct% free ($([math]::Round($_.FreeSpace/1GB)) GB)"
        if ($pct -lt 10) { Write-Bad $msg } elseif ($pct -lt 20) { Write-Warn2 $msg } else { Write-Ok $msg }
    }

    try {
        $mp = Get-MpComputerStatus
        if ($mp.RealTimeProtectionEnabled) { Write-Ok 'Defender real-time protection ON' } else { Write-Bad 'Defender real-time protection OFF' }
        $age = (Get-Date) - $mp.AntivirusSignatureLastUpdated
        if ($age.TotalDays -gt 3) { Write-Warn2 "Defender signatures are $([int]$age.TotalDays) days old" } else { Write-Ok 'Defender signatures up to date' }
    } catch { Write-Warn2 'Could not read Defender status (third-party AV installed?)' }

    Get-NetFirewallProfile | ForEach-Object {
        if ($_.Enabled) { Write-Ok "Firewall $($_.Name) ON" } else { Write-Bad "Firewall $($_.Name) OFF" }
    }

    $startup = @()
    foreach ($k in 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run','HKLM:\Software\Microsoft\Windows\CurrentVersion\Run') {
        if (Test-Path $k) { $startup += (Get-ItemProperty $k).PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' } }
    }
    if ($startup.Count -gt 10) { Write-Warn2 "$($startup.Count) startup programs (see Optimizer > startup manager)" } else { Write-Ok "$($startup.Count) startup programs" }

    $top = Get-Process | Sort-Object WS -Descending | Select-Object -First 5
    Write-Host "`n  Top RAM users:"
    $top | ForEach-Object { Write-Host ("    {0,-25} {1,6:N0} MB" -f $_.ProcessName, ($_.WS/1MB)) }
}

function Invoke-DefenderScan {
    Write-Head 'Windows Defender'
    Write-Host '  Updating signatures...'; try { Update-MpSignature } catch { Write-Warn2 $_.Exception.Message }
    Write-Host '  Running quick scan...';  try { Start-MpScan -ScanType QuickScan; Write-Ok 'Scan finished.' } catch { Write-Warn2 $_.Exception.Message }
    Get-MpThreatDetection -ErrorAction SilentlyContinue | Select-Object -First 10 | Format-Table ThreatID, InitialDetectionTime, Resources -AutoSize
}

# ---------------------------------------------------------------- Optimizer
function New-Backup {
    Write-Host '  Creating restore point (so you can undo everything)...'
    try {
        Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore' 'SystemRestorePointCreationFrequency' 0 | Out-Null
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description 'PCTool before optimize' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        Write-Ok 'Restore point created.'
    } catch { Write-Warn2 "Restore point failed: $($_.Exception.Message)" }
}

function Optimize-Power {
    $out = powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>&1
    $m = [regex]::Match("$out", '[0-9a-fA-F-]{36}')
    if ($m.Success) { powercfg -setactive $m.Value; Write-Ok 'Ultimate Performance power plan active' }
    else { powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e27be5e18c; Write-Ok 'High Performance power plan active' }
    Write-Host '        (laptops: this drains battery faster - switch back on battery if needed)' -ForegroundColor DarkGray
}

function Optimize-Gaming {
    Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode' 1 | Out-Null
    Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' 1 | Out-Null
    Set-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0 | Out-Null
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0 | Out-Null
    Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' 2 | Out-Null
    # Games get priority for CPU/GPU scheduling
    $g = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'
    Set-Reg $g 'GPU Priority' 8 | Out-Null
    Set-Reg $g 'Priority' 6 | Out-Null
    Set-Reg $g 'Scheduling Category' 'High' 'String' | Out-Null
    Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' 'SystemResponsiveness' 10 | Out-Null
    Write-Ok 'Game Mode on, Game DVR off, GPU scheduling (HAGS) on, game CPU/GPU priority raised'
    Write-Host '        (HAGS needs a reboot to take effect)' -ForegroundColor DarkGray
}

function Optimize-Visuals {
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' 'VisualFXSetting' 2 | Out-Null
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency' 0 | Out-Null
    Set-Reg 'HKCU:\Control Panel\Desktop\WindowMetrics' 'MinAnimate' '0' 'String' | Out-Null
    Write-Ok 'Transparency and window animations off (sign out/in to fully apply)'
}

function Optimize-Mouse {
    Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseSpeed' '0' 'String' | Out-Null
    Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseThreshold1' '0' 'String' | Out-Null
    Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseThreshold2' '0' 'String' | Out-Null
    Write-Ok 'Mouse acceleration ("Enhance pointer precision") off'
}

function Optimize-Network {
    ipconfig /flushdns | Out-Null
    Write-Ok 'DNS cache flushed'
}

function Clear-Junk {
    $before = (Get-PSDrive -Name ($env:SystemDrive.TrimEnd(':'))).Free
    foreach ($d in $env:TEMP, "$env:SystemRoot\Temp", "$env:LOCALAPPDATA\Microsoft\Windows\INetCache", "$env:LOCALAPPDATA\D3DSCache") {
        if (Test-Path $d) { Get-ChildItem $d -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue }
    }
    try { Clear-RecycleBin -Force -ErrorAction SilentlyContinue } catch {}
    $after = (Get-PSDrive -Name ($env:SystemDrive.TrimEnd(':'))).Free
    Write-Ok ("Cleaned temp/cache files, freed {0:N0} MB" -f (($after - $before)/1MB))
}

function Manage-Startup {
    Write-Head 'Startup manager'
    $items = @()
    foreach ($k in 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run','HKLM:\Software\Microsoft\Windows\CurrentVersion\Run') {
        if (Test-Path $k) {
            (Get-ItemProperty $k).PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' } |
                ForEach-Object { $items += [pscustomobject]@{ Key=$k; Name=$_.Name; Value=$_.Value } }
        }
    }
    if (-not $items) { Write-Ok 'No registry startup entries.'; return }
    for ($i = 0; $i -lt $items.Count; $i++) { Write-Host ("  [{0}] {1}  ->  {2}" -f $i, $items[$i].Name, $items[$i].Value) }
    $pick = Read-Host "`n  Numbers to disable (comma separated, Enter to skip)"
    if (-not $pick) { return }
    $items | ConvertTo-Json | Set-Content (Join-Path $Script:Dir ("startup-backup-{0:yyyyMMdd-HHmmss}.json" -f (Get-Date)))
    foreach ($n in $pick -split ',') {
        $n = $n.Trim()
        if ($n -match '^\d+$' -and [int]$n -lt $items.Count) {
            $it = $items[[int]$n]
            Remove-ItemProperty -Path $it.Key -Name $it.Name -ErrorAction SilentlyContinue
            Write-Ok "Removed from startup: $($it.Name) (backup saved in $Script:Dir)"
        }
    }
}

function Invoke-OptimizeAll {
    Write-Head 'Full optimize'
    New-Backup
    Optimize-Power; Optimize-Gaming; Optimize-Visuals; Optimize-Mouse; Optimize-Network; Clear-Junk
    Write-Host "`n  Done. Reboot to apply everything." -ForegroundColor Green
}

# ---------------------------------------------------------------- Menu
function Show-Menu {
    Clear-Host
    Write-Host '  ==============================' -ForegroundColor Cyan
    Write-Host '        PCTool  v1.0' -ForegroundColor Cyan
    Write-Host '  ==============================' -ForegroundColor Cyan
    Write-Host '  CHECKER'
    Write-Host '   1. System health check'
    Write-Host '   2. VirusTotal scan (running programs + startup + Downloads/AppData/Temp)'
    Write-Host '   3. VirusTotal scan a specific file or folder'
    Write-Host '   4. Windows Defender update + quick scan'
    Write-Host '  OPTIMIZER'
    Write-Host '   5. FULL OPTIMIZE (restore point + everything below)'
    Write-Host '   6. Power plan (Ultimate Performance)'
    Write-Host '   7. Gaming tweaks (Game Mode, GPU scheduling, priority, no Game DVR)'
    Write-Host '   8. Visual effects off'
    Write-Host '   9. Mouse acceleration off'
    Write-Host '  10. Clean temp/cache files'
    Write-Host '  11. Startup manager'
    Write-Host '   0. Exit'
}

if (-not (Test-Admin)) {
    Write-Host 'Please run this from an Administrator terminal (right-click cmd > Run as administrator).' -ForegroundColor Red
    return
}

while ($true) {
    Show-Menu
    switch (Read-Host "`n  Choose") {
        '1'  { Invoke-SystemCheck }
        '2'  { Invoke-VTScan }
        '3'  { Invoke-VTScan (Read-Host '  Path to file or folder') }
        '4'  { Invoke-DefenderScan }
        '5'  { Invoke-OptimizeAll }
        '6'  { Optimize-Power }
        '7'  { New-Backup; Optimize-Gaming }
        '8'  { Optimize-Visuals }
        '9'  { Optimize-Mouse }
        '10' { Clear-Junk }
        '11' { Manage-Startup }
        '0'  { return }
        default { Write-Warn2 'Invalid choice' }
    }
    Read-Host "`n  Press Enter to return to menu"
}
