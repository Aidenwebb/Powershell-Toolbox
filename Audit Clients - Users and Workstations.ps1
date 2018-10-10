
# Parameters
param
(
    [Parameter(Mandatory=$true)]
    [string]$desktopOUDN,
    [Parameter(Mandatory=$true)]
    [string]$laptopOUDN,
    [Parameter(Mandatory=$true)]
    [string]$internalAccOUDN, 
    [Parameter()] 
    [ValidateRange(14, [int]::MaxValue)] # Minimum 14 as LastLoginTimeStamp AD Attribute only updates if the previous value is more than 14 days in the past 
    [int]$maxWorkstationLogonTimeStamp = 90, # The number of days a workstation hasn't checked in with the domain before they are automatically excluded from audit. 
    [Parameter()] 
    [ValidateRange(14, [int]::MaxValue)] # Minimum 14 as LastLoginTimeStamp AD Attribute only updates if the previous value is more than 14 days in the past 
    [int]$maxUserLogonTimeStamp = 90 # The number of days a user hasn't checked in with the domain before they are automatically excluded from audit. 
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