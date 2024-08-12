

function Test-Administrator  
{  
    [OutputType([bool])]
    param()
    process {
        [Security.Principal.WindowsPrincipal]$user = [Security.Principal.WindowsIdentity]::GetCurrent();
        return $user.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator);
    }
}

Write-host $env:COMPUTERNAME     -ForegroundColor Magenta
Write-host $env:USERNAME         -ForegroundColor Magenta
Write-host $env:USERDNSDOMAIN    -ForegroundColor Magenta

whoami     | Write-host          -ForegroundColor Magenta

sc.exe queryex type= service state= all | Select-String -Pattern "actions.runner" -CaseSensitive -SimpleMatch | Write-host          -ForegroundColor Magenta
# sc.exe config "actions.runner.wenchiehlee-Win11Deploy.TAICLTB37TMOCQ7" obj= "NT AUTHORITY\SYSTEM" type= own

if(-not (Test-Administrator))
{
    Write-Error "This script must be executed as Administrator.";
    exit 1;
}

choco install -y wsl2

choco upgrade all -y
