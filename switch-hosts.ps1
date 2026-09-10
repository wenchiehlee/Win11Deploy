# switch-hosts.ps1
# Pure ASCII script. Optimized for ZERO-FLASHING and THROTTLED notifications.
param([switch]$NotifyOnly)

$sharedDir  = "C:\ProgramData\MarsHostSwitcher"
if (-not (Test-Path $sharedDir)) { New-Item -ItemType Directory -Path $sharedDir -Force | Out-Null }
$logFile    = "$sharedDir\MarsHostSwitcher.log"
$resultFile = "$sharedDir\MarsHostSwitcher.result"

# --- THROTTLE CHECK ---
$throttleKey = if ($NotifyOnly) { "notify" } else { "main" }
$lastRunFile = "$sharedDir\MarsHostSwitcher.$throttleKey.lastrun"
if (Test-Path $lastRunFile) {
    $lastRunRaw = Get-Content $lastRunFile | Select-Object -Last 1
    if ($lastRunRaw) {
        try {
            $lastRunTime = Get-Date $lastRunRaw
            if ((Get-Date) -lt $lastRunTime.AddSeconds(10)) {
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Throttled (Ran too recently)" | Out-File $logFile -Append -Encoding UTF8
                Exit
            }
        } catch {}
    }
}
Get-Date | Set-Content $lastRunFile

function Show-Notification {
    param([string]$Title, [string]$Message)
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        $icon = [System.Windows.Forms.NotifyIcon]::new()
        $icon.Icon = [System.Drawing.SystemIcons]::Information
        $icon.Visible = $true
        $icon.BalloonTipTitle = $Title
        $icon.BalloonTipText  = $Message
        $icon.ShowBalloonTip(5000)
        Start-Sleep -Milliseconds 6000
        $icon.Dispose()
    } catch {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Notification Error: $_" | Out-File $logFile -Append -Encoding UTF8
    }
}

# =============================================================
# NOTIFY-ONLY MODE: wait for SYSTEM task result, then show toast
# =============================================================
if ($NotifyOnly) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - NotifyOnly: waiting for sync result..." | Out-File $logFile -Append -Encoding UTF8

    # Poll up to 40 seconds for a FRESH result file (written within last 60s)
    $waited = 0
    $result = $null
    while ($waited -lt 40) {
        if (Test-Path $resultFile) {
            $age = (Get-Date) - (Get-Item $resultFile).LastWriteTime
            if ($age.TotalSeconds -lt 60) {
                $result = Get-Content $resultFile | Select-Object -Last 1
                Remove-Item $resultFile -Force -ErrorAction SilentlyContinue
                break
            }
        }
        Start-Sleep -Seconds 2
        $waited += 2
    }

    if (-not $result) {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - NotifyOnly: Timeout waiting for sync result, no toast shown." | Out-File $logFile -Append -Encoding UTF8
        Exit
    }

    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - NotifyOnly: result=$result" | Out-File $logFile -Append -Encoding UTF8

    # Only show toast if SYSTEM task succeeded
    if ($result -match "^SUCCESS:(True|False)$") {
        $atHome = $Matches[1] -eq "True"
        if ($atHome) {
            $title = [char]0x5728 + [char]0x5BB6 + " - Mars " + [char]0x5DF2 + [char]0x9023 + [char]0x7DDA
            $msg   = "NAS " + [char]0x8A2D + [char]0x5B9A + [char]0x5DF2 + [char]0x540C + [char]0x6B65 + [char]0x3002
        } else {
            $title = [char]0x5916 + [char]0x51FA + " - " + [char]0x5DF2 + [char]0x96E2 + [char]0x958B + " Mars"
            $msg   = "NAS " + [char]0x8A2D + [char]0x5B9A + [char]0x5DF2 + [char]0x505C + [char]0x7528 + [char]0x3002
        }
        Show-Notification -Title $title -Message $msg
    }
    Exit
}

# =============================================================
# SYSTEM MODE: detect network, sync hosts, write result file
# =============================================================
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Script started (Admin: $isAdmin)" | Out-File $logFile -Append -Encoding UTF8

# Wait for network stability
Start-Sleep -Seconds 10

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $scriptRoot) { $scriptRoot = Get-Location }
$templateFile = Join-Path $scriptRoot "hosts.template"
$hostsPath    = "C:\Windows\System32\drivers\etc\hosts"
$synologyIP   = "192.168.31.101"
$homeSSIDPattern = "*Mars*"

if (-not (Test-Path $templateFile)) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Error: hosts.template not found at $templateFile" | Out-File $logFile -Append -Encoding UTF8
    "FAILED" | Set-Content $resultFile
    Exit
}

if (-not $isAdmin) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Warning: Not running as Admin. Cannot sync hosts." | Out-File $logFile -Append -Encoding UTF8
    "FAILED" | Set-Content $resultFile
    Exit
}

$currentNetworks = Get-NetConnectionProfile | Select-Object -ExpandProperty Name
$isMars = $false
foreach ($net in $currentNetworks) {
    if ($net -like $homeSSIDPattern) { $isMars = $true; break }
}
$canPing = Test-Connection -ComputerName $synologyIP -Count 1 -Quiet
$atHome  = ($isMars -or $canPing)
"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Network: $($currentNetworks -join ', '), IsMars: $isMars, CanPing: $canPing" | Out-File $logFile -Append -Encoding UTF8

# --- Cisco AnyConnect DNS Fix ---
$adapterName = "Ethernet 2"
try {
    $adapter = Get-NetAdapter -Name $adapterName -ErrorAction SilentlyContinue
    if ($adapter) {
        if ($atHome) {
            if ($adapter.Status -ne "Disabled") {
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - At home: Disabling $adapterName to fix DNS issues." | Out-File $logFile -Append -Encoding UTF8
                Disable-NetAdapter -Name $adapterName -Confirm:$false
            }
        } else {
            if ($adapter.Status -eq "Disabled") {
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Away: Enabling $adapterName for potential VPN use." | Out-File $logFile -Append -Encoding UTF8
                Enable-NetAdapter -Name $adapterName -Confirm:$false
            }
        }
    }
} catch {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Error toggling $($adapterName): $_" | Out-File $logFile -Append -Encoding UTF8
}

$startMarker   = "# === SYNOLOGY START ==="
$endMarker     = "# === SYNOLOGY END ==="
$templateLines = Get-Content $templateFile
if (-not $atHome) {
    $templateLines = $templateLines | ForEach-Object { if ($_ -match "\S" -and $_ -notmatch "^#") { "#" + $_ } else { $_ } }
}

$maxRetries = 15
$retryCount = 0
$success    = $false
while (-not $success -and $retryCount -lt $maxRetries) {
    try {
        $ErrorActionPreference = "Stop"
        $currentHosts = Get-Content $hostsPath
        $newHosts     = @()
        $inSection    = $false
        $sectionFound = $false
        foreach ($line in $currentHosts) {
            if ($line -eq $startMarker) {
                $inSection = $true; $sectionFound = $true
                $newHosts += $startMarker
                $newHosts += $templateLines
                continue
            }
            if ($line -eq $endMarker) {
                $inSection = $false
                $newHosts += $endMarker
                continue
            }
            if (-not $inSection) { $newHosts += $line }
        }
        if (-not $sectionFound) {
            $newHosts += "`n$startMarker"
            $newHosts += $templateLines
            $newHosts += $endMarker
        }
        $newHosts | Set-Content $hostsPath -Encoding ASCII
        $success = $true
    } catch {
        $retryCount++
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Sync retry $retryCount due to: $_" | Out-File $logFile -Append -Encoding UTF8
        Start-Sleep -Seconds 1
    }
}

if ($success) {
    ipconfig /flushdns
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Sync success (AtHome: $atHome)" | Out-File $logFile -Append -Encoding UTF8
    "SUCCESS:$atHome" | Set-Content $resultFile
} else {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Sync FAILED after $maxRetries retries." | Out-File $logFile -Append -Encoding UTF8
    "FAILED" | Set-Content $resultFile
}

