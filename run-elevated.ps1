# run-elevated.ps1
# Desktop-shortcut entry point. Launched already elevated (the shortcut's
# launcher exe has a requireAdministrator manifest, so Explorer/UAC prompts
# for an admin password before this runs, since the account here is a
# standard domain user). Runs the hosts sync and then shows the toast
# notification, both in this same admin process.
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $scriptDir "switch-hosts.ps1")
& (Join-Path $scriptDir "switch-hosts.ps1") -NotifyOnly
