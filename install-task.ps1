# install-task.ps1
# 此腳本用於將 switch-hosts.ps1 註冊到工作排程器，以實現自動切換。

if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Please run as Administrator!"
    Pause
    Break
}

$taskName       = "MarsHostSwitcher"
$notifyTaskName = "MarsHostSwitcherNotify"
$oldTaskName    = "SyncSynologyHosts"
$scriptPath     = Join-Path (Get-Location) "switch-hosts.ps1"

if (-not (Test-Path $scriptPath)) {
    Write-Error "Could not find switch-hosts.ps1!"
    Pause
    Break
}

# 移除舊任務（如果存在）
foreach ($old in @($oldTaskName, $taskName, $notifyTaskName)) {
    if (Get-ScheduledTask -TaskName $old -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $old -Confirm:$false
        Write-Host "Removed old task '$old'."
    }
}

# 建立捷徑以註冊 AppID: 網路設定
$shortcutName = "網路設定"
$shortcutPath = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\$shortcutName.lnk"
if (-not (Test-Path $shortcutPath)) {
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($shortcutPath)
    $Shortcut.TargetPath = "powershell.exe"
    $Shortcut.Save()
}

$userSid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value

# --- 共用 Trigger 區段 ---
$triggers = @"
  <Triggers>
    <LogonTrigger>
      <Enabled>true</Enabled>
    </LogonTrigger>
    <SessionStateChangeTrigger>
      <Enabled>true</Enabled>
      <StateChange>SessionUnlock</StateChange>
    </SessionStateChangeTrigger>
    <EventTrigger>
      <Enabled>true</Enabled>
      <Delay>PT5S</Delay>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="Microsoft-Windows-NetworkProfile/Operational"&gt;&lt;Select Path="Microsoft-Windows-NetworkProfile/Operational"&gt;*[System[(EventID=10000)]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
  </Triggers>
"@

# --- 共用 Settings 區段 ---
$settings = @"
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>true</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT72H</ExecutionTimeLimit>
    <Priority>7</Priority>
    <Compatibility>4</Compatibility>
    <RestartOnFailure>
      <Interval>PT1M</Interval>
      <Count>3</Count>
    </RestartOnFailure>
  </Settings>
"@

# =============================================================
# Task 1: MarsHostSwitcher — 以 SYSTEM 執行，負責修改 hosts 檔案
# =============================================================
$mainTaskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Date>$(Get-Date -Format "yyyy-MM-ddTHH:mm:ss")</Date>
    <Author>$env:COMPUTERNAME\$env:USERNAME</Author>
    <Description>Runs as SYSTEM to update hosts file when network changes.</Description>
  </RegistrationInfo>
$triggers
  <Principals>
    <Principal id="Author">
      <UserId>S-1-5-18</UserId>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
$settings
  <Actions Context="Author">
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "$scriptPath"</Arguments>
    </Exec>
  </Actions>
</Task>
"@

# =============================================================
# Task 2: MarsHostSwitcherNotify — 以目前用戶執行，負責顯示 Toast 通知
# =============================================================
$notifyTaskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Date>$(Get-Date -Format "yyyy-MM-ddTHH:mm:ss")</Date>
    <Author>$env:COMPUTERNAME\$env:USERNAME</Author>
    <Description>Runs as current user to show Toast notification when network changes.</Description>
  </RegistrationInfo>
$triggers
  <Principals>
    <Principal id="Author">
      <UserId>$userSid</UserId>
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>LeastPrivilege</RunLevel>
    </Principal>
  </Principals>
$settings
  <Actions Context="Author">
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "$scriptPath" -NotifyOnly</Arguments>
    </Exec>
  </Actions>
</Task>
"@

# 註冊兩個任務
Register-ScheduledTask -Xml $mainTaskXml   -TaskName $taskName       -Force
Register-ScheduledTask -Xml $notifyTaskXml -TaskName $notifyTaskName -Force

# --- 修正共用狀態目錄權限 ---
# SYSTEM 任務會先建立 log/lastrun/result 檔案，若不明確授權一般使用者
# 寫入權限，Notify 任務（以目前使用者身分執行）會在寫入時遇到 Access Denied，
# 導致通知悄悄失效但工作排程器仍回報「成功」。
$sharedDir = "C:\ProgramData\MarsHostSwitcher"
if (-not (Test-Path $sharedDir)) { New-Item -ItemType Directory -Path $sharedDir -Force | Out-Null }
icacls $sharedDir /grant "*S-1-5-32-545:(OI)(CI)M" /T | Out-Null
Write-Host "  Granted Users modify access on '$sharedDir'" -ForegroundColor Cyan

# --- 授權目前使用者可手動「立即執行」這兩個工作 ---
# Register-ScheduledTask 預設只把 SYSTEM 任務的執行權限給 Administrators/SYSTEM，
# 一般使用者（例如桌面捷徑點擊者）完全沒有權限觸發 Run()，會得到 Access Denied。
# 這裡明確把「立即執行」權限授予目前這個使用者帳號。
$sch = New-Object -ComObject "Schedule.Service"
$sch.Connect()
$rootFolder = $sch.GetFolder("\")
$grantSddl = "(A;;0x1f019f;;;$userSid)"
foreach ($tn in @($taskName, $notifyTaskName)) {
    $t = $rootFolder.GetTask($tn)
    $sd = $t.GetSecurityDescriptor(4)
    if ($sd -notlike "*(A;;0x1f019f;;;$userSid)*") {
        $t.SetSecurityDescriptor($sd + $grantSddl, 0)
    }
}
Write-Host "  Granted '$env:USERNAME' rights to manually run both tasks" -ForegroundColor Cyan

Write-Host ""
Write-Host "Successfully installed tasks:" -ForegroundColor Green
Write-Host "  '$taskName'       — runs as SYSTEM, modifies hosts file" -ForegroundColor Cyan
Write-Host "  '$notifyTaskName' — runs as $env:USERNAME, shows Toast notification" -ForegroundColor Cyan
Write-Host ""
Write-Host "Both tasks trigger on: Logon / Network change / Workstation unlock"
