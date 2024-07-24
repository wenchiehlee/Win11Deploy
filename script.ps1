
$env:COMPUTERNAME
$env:USERNAME
$env:USERDNSDOMAIN

# Query all action runner instance in this runner..
Get-Service "action*"

choco upgrade all -y
