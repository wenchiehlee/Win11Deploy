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

A one-click "Mars Host Switch" desktop shortcut runs `MarsHostSwitchLauncher.exe`,
a tiny compiled (non-console) launcher that asks the Task Scheduler service to
start the two already-registered tasks above right now. It does **not**
elevate itself (`asInvoker`) — the elevated execution context is already baked
into the `MarsHostSwitcher` task, and `install-task.ps1` grants the installing
user explicit rights to trigger it on demand. Result: a single click, no UAC
prompt, no admin-password prompt (important on this machine since the account
is a standard domain user, not a local admin), and no console window flash.

`MarsHostSwitchLauncher.exe` is built from `MarsHostSwitchLauncher.cs` by
`install-task.ps1` (via `csc.exe`) — it's gitignored, not committed.

> Note: this machine's security policy blocks `CreateObject` calls from a
> non-elevated `wscript.exe`/`cscript.exe` process (raises `800A0046
> Permission denied`), so nothing here uses a `.vbs` launcher. The compiled
> launcher calls the Task Scheduler COM API directly instead (late-bound via
> reflection, not `CreateObject`), and `MarsHostSwitcherNotify`'s scheduled
> action calls `powershell.exe` directly rather than through a `.vbs` wrapper.

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
| `MarsHostSwitchLauncher.cs` | Source for the desktop shortcut's silent, non-elevating launcher |
| `install-task.ps1` | Registers the two scheduled tasks, fixes their permissions, compiles the launcher and (re)creates the desktop shortcut |
| `hosts.template` | NAS host entries to inject into the hosts file |

Shared runtime state is stored in `C:\ProgramData\MarsHostSwitcher\`.

### Logs

```
C:\ProgramData\MarsHostSwitcher\MarsHostSwitcher.log
```
