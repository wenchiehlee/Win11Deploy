
$env:COMPUTERNAME
$env:USERNAME
$env:USERDNSDOMAIN

# Query all action runner instance in this runner..
Get-Service "action*" | powershell Format-Table -AutoSize

choco upgrade all -y
