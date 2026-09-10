using System.Diagnostics;
using System.IO;

// Action target for the MarsHostSwitcherNotify scheduled task.
// Compiled as a GUI-subsystem exe (no console window is ever created,
// unlike a plain powershell.exe -WindowStyle Hidden invocation, which
// still briefly flashes a console on this Windows Terminal-as-default-host
// setup). Runs as the interactive user already (no elevation needed here).
class NotifyLauncher
{
    static void Main()
    {
        string exeDir = Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location);
        string scriptPath = Path.Combine(exeDir, "switch-hosts.ps1");

        var psi = new ProcessStartInfo("powershell.exe",
            "-NoProfile -ExecutionPolicy Bypass -File \"" + scriptPath + "\" -NotifyOnly");
        psi.CreateNoWindow = true;
        psi.UseShellExecute = false;
        psi.WindowStyle = ProcessWindowStyle.Hidden;
        Process.Start(psi);
    }
}
