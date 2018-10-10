
# Parameters
param
(
    [Parameter(Mandatory=$true)]
    [string]$desktopOUDN,
    [Parameter(Mandatory=$true)]
    [string]$laptopOUDN,
    [Parameter(Mandatory=$true)]
    [string]$internalAccOUDN
)

$excludeFromReportString = "Exclude from user and workstation audit"
$clientname = (Get-ADDomain).name
 
# Get all users in Internal Accounts/Standard OU that are not generic accounts
$users = Get-ADUser -Filter * -SearchBase $internalAccOUDN -Properties info | where info -NotMatch $excludeFromReportString
$usersCount = ($users | Measure-Object).Count
 
 
# Get all desktops, laptops, then add the number together. We don't bill per Server.
 $computersDesktops = (Get-ADObject -filter {ObjectClass -eq "computer"} -SearchBase $desktopOUDN -Properties description | where description -NotMatch $excludeFromReportString | Measure-Object).count
$computerLaptops = (Get-ADObject -filter {ObjectClass -eq "computer"} -SearchBase $laptopOUDN -Properties description | where description -NotMatch $excludeFromReportString | Measure-Object).count 


 
$totalComputers = $computersDesktops + $computerLaptops
 
Write-Host "Client: $clientname"
Write-Host "Total Users: $usersCount"
Write-Host "Total Computers: $totalComputers"

Write-Host "Below is a list of users counted. If any of these should not be included in future reports, please add '$excludeFromReportString' to the telephone>notes field of the user object"
Write-Host "Counted Users:"
 
# List usernames for users - sanity check.

foreach ($user in $users) {
$username = $user.Name
 
Write-Host $username}