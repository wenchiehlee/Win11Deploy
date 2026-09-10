using System.Diagnostics;
using System.IO;

// Desktop-shortcut launcher. Compiled as a GUI-subsystem exe (no console
// window is ever created) with a requireAdministrator manifest, so a click
// triggers a single UAC prompt (a password prompt on this machine, since
// the account is a standard domain user, not a local admin) instead of
// requiring you to open a console and run the script by hand.
//
// Not a .vbs launcher because this machine's security policy blocks
// CreateObject from a non-elevated wscript.exe/cscript.exe (error 800A0046).
class HiddenLauncher
{
    static void Main()
    {
        string exeDir = Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location);
        string scriptPath = Path.Combine(exeDir, "run-elevated.ps1");

        var psi = new ProcessStartInfo("powershell.exe",
            "-NoProfile -ExecutionPolicy Bypass -File \"" + scriptPath + "\"");
        psi.CreateNoWindow = true;
        psi.UseShellExecute = false;
        psi.WindowStyle = ProcessWindowStyle.Hidden;
        Process.Start(psi);
    }
}
