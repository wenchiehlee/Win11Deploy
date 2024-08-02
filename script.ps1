
Write-Output $env:COMPUTERNAME     -ForegroundColor Magenta
Write-Output $env:USERNAME         -ForegroundColor Magenta
Write-Output $env:USERDNSDOMAIN    -ForegroundColor Magenta

whoami

sc.exe queryex type= service state= all | find /i "actions.runner"
# sc config "actions.runner.wenchiehlee-Win11Deploy.TAICLTB37TMOCQ7" obj= "NT AUTHORITY\SYSTEM" type= own
choco upgrade all -y
