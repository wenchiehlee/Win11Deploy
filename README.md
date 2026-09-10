# Win11

WorkingSpace for Win11

## MarsHostSwitcher

Automatically switches `hosts` file entries for Synology NAS when the network changes between home (Mars Wi-Fi) and office.

### How it works

Two scheduled tasks work together:

| Task | Runs As | Role |
|------|---------|------|
| `MarsHostSwitcher` | SYSTEM | Modifies hosts file + flushes DNS |
| `MarsHostSwitcherNotify` | Current user | Shows balloon notification |

Both tasks trigger on: **Login / Network change / Workstation unlock**

The notification only appears when the hosts sync actually succeeded.

`install-task.ps1` also grants the installing user explicit "run now" rights on
both tasks (Task Scheduler denies this by default for a task whose action runs
as SYSTEM) and write access to the shared state folder, so the desktop
shortcut below can trigger a sync on demand.

### Desktop shortcut (manual trigger)

A one-click "Mars Host Switch" desktop shortcut runs `run-elevated.ps1`
(which in turn calls `switch-hosts.ps1` then `switch-hosts.ps1 -NotifyOnly`)
directly as Administrator — the shortcut has its "Run as administrator" flag
set on the `.lnk` file itself, so a single click prompts UAC once (or, on a
machine where the user is already a local admin with UAC's Admin Approval
Mode relaxed, elevates silently) instead of requiring you to open a console
and run the script by hand.

> Note: this machine's security policy blocks `CreateObject` calls from a
> non-elevated `wscript.exe`/`cscript.exe` process (raises `800A0046
> Permission denied`). That's why nothing here uses a `.vbs` launcher for
> silent background execution — `switch-hosts.ps1` hides its own console
> window via a `ShowWindow` P/Invoke instead.

### Install

> Requires **Administrator** privileges.

```powershell
cd C:\path\to\Win11
.\install-task.ps1
```

### Files

| File | Description |
|------|-------------|
| `switch-hosts.ps1` | Main script (`-NotifyOnly` flag for notify-only mode) |
| `run-elevated.ps1` | Entry point for the desktop shortcut; runs sync + notify as Administrator |
| `install-task.ps1` | Registers the two scheduled tasks and fixes their permissions |
| `hosts.template` | NAS host entries to inject into the hosts file |

Shared runtime state is stored in `C:\ProgramData\MarsHostSwitcher\`.

### Logs

```
C:\ProgramData\MarsHostSwitcher\MarsHostSwitcher.log
```
