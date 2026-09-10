# run-elevated.ps1
# Desktop-shortcut entry point. Meant to be launched already elevated
# (via the shortcut's "Run as administrator" flag). Runs the hosts sync
# and then shows the toast notification, both in this same admin process.

# -WindowStyle Hidden still lets the console flash briefly on some hosts
# (e.g. Windows Terminal as default terminal app); hide it immediately instead.
Add-Type -Name Win -Namespace Console -MemberDefinition '
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int cmdShow);
'
[Console.Win]::ShowWindow([Console.Win]::GetConsoleWindow(), 0) | Out-Null

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $scriptDir "switch-hosts.ps1")
& (Join-Path $scriptDir "switch-hosts.ps1") -NotifyOnly
