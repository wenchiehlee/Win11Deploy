
Write-host $env:COMPUTERNAME     -ForegroundColor Magenta
Write-host $env:USERNAME         -ForegroundColor Magenta
Write-host $env:USERDNSDOMAIN    -ForegroundColor Magenta

whoami     | Write-host          -ForegroundColor Magenta

sc.exe queryex type= service state= all | Select-String -Pattern "actions.runner" -CaseSensitive -SimpleMatch
# sc config "actions.runner.wenchiehlee-Win11Deploy.TAICLTB37TMOCQ7" obj= "NT AUTHORITY\SYSTEM" type= own
choco upgrade all -y
