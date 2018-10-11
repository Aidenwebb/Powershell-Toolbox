### Output a count of billable, excluded and inactive users and workstations.
### Billable is defined as a user or computer that is not explicitly excluded, and is has logged in within the number of days specified in the maxXLogonTimeStamp parameters
### maxWorkstationLogonTimeStamp and maxUserLogonTimeStamp both default to 90 days

# Parameters
param
(
    [Parameter(Mandatory=$true)]
    [string]$desktopOUDN,
    [Parameter(Mandatory=$true)]
    [string]$laptopOUDN,
    [Parameter(Mandatory=$true)]
    [string]$internalAccOUDN, 
    [Parameter(Mandatory=$true)] 
    [string]$externalAccOUDN, 
    [Parameter()] 
    [ValidateRange(14, [int]::MaxValue)] # Minimum 14 as LastLoginTimeStamp AD Attribute only updates if the previous value is more than 14 days in the past 
    [int]$maxWorkstationLogonTimeStamp = 90, # The number of days a workstation hasn't checked in with the domain before they are automatically excluded from audit. 
    [Parameter()] 
    [ValidateRange(14, [int]::MaxValue)] # Minimum 14 as LastLoginTimeStamp AD Attribute only updates if the previous value is more than 14 days in the past 
    [int]$maxUserLogonTimeStamp = 90 # The number of days a user hasn't checked in with the domain before they are automatically excluded from audit. 
)

### Output script parameters so if there's a problem we can check for obvious mistakes.

Write-Host "---DEBUG---"
Write-Host "---Version 1.1---"
Write-Host "Desktop OU: $desktopOUDN"
Write-Host "Laptop OU: $laptopOUDN"
Write-Host "Internal Accounts OU: $internalAccOUDN"
Write-Host "External Accounts OU: $externalAccOUDN"
Write-Host "Workstations considered inactive after: $maxWorkstationLogonTimeStamp days"
Write-Host "Users considered inactive after: $maxUserLogonTimeStamp days"
Write-Host "--------------------------------------"
Write-Host ""

$maxUserTimeStampAsFileTime = (Get-Date).AddDays(-$maxUserLogonTimeStamp).ToFileTime().toString()
$maxWorkstationTimeStampAsFileTime = (Get-Date).AddDays(-$maxWorkstationLogonTimeStamp).ToFileTime().toString()

$excludeFromReportString = "Exclude from user and workstation audit"
$clientname = (Get-ADDomain).name
 
# Get all users in Internal OU's 
$includedInternalUsers = get-aduser -Filter {lastLogonTimeStamp -ge $maxUserTimeStampAsFileTime} -SearchBase $internalAccOUDN -Properties info, LastLogonTimeStamp | where info -NotMatch $excludeFromReportString
$excludedInternalUsers = get-aduser -Filter * -SearchBase $internalAccOUDN -Properties info, LastLogonTimeStamp | where info -Match $excludeFromReportString
$inactiveInternalUsers = get-aduser -Filter {lastLogonTimeStamp -lt $maxUserTimeStampAsFileTime} -SearchBase $internalAccOUDN  -Properties lastLogonTimeStamp

# Get all users in the External OU's
$includedExternalUsers = get-aduser -Filter {lastLogonTimeStamp -ge $maxUserTimeStampAsFileTime} -SearchBase $externalAccOUDN -Properties info, LastLogonTimeStamp | where info -NotMatch $excludeFromReportString
$excludedExternalUsers = get-aduser -Filter * -SearchBase $externalAccOUDN -Properties info, LastLogonTimeStamp | where info -Match $excludeFromReportString
$inactiveExternalUsers = get-aduser -Filter {lastLogonTimeStamp -lt $maxUserTimeStampAsFileTime} -SearchBase $externalAccOUDN -Properties lastLogonTimeStamp

# Combine the lists for counting and reporting
$billableUsers = $includedInternalUsers + $includedExternalUsers
$excludedUsers = $excludedInternalUsers + $excludedExternalUsers
$inactiveUsers = $inactiveInternalUsers + $inactiveExternalUsers
 
### We bill for desktops and laptops, but not for servers.

# Get all computers in the Desktops OU
$includedDesktops = get-adcomputer -Filter {lastLogonTimeStamp -ge $maxWorkstationTimeStampAsFileTime} -SearchBase $desktopOUDN -Properties description | where description -NotMatch $excludeFromReportString
$excludedDesktops = get-adcomputer -Filter * -SearchBase $desktopOUDN -Properties description | where description -Match $excludeFromReportString
$inactiveDesktops = get-adcomputer -Filter {lastLogonTimeStamp -lt $maxWorkstationTimeStampAsFileTime} -SearchBase $desktopOUDN -Properties description, lastLogonTimeStamp 

# Get all computers in the Laptops OU
$includedLaptops = get-adcomputer -Filter {lastLogonTimeStamp -ge $maxWorkstationTimeStampAsFileTime} -SearchBase $laptopOUDN -Properties description | where description -NotMatch $excludeFromReportString
$excludedLaptops = get-adcomputer -Filter * -SearchBase $laptopOUDN -Properties description | where description -Match $excludeFromReportString
$inactiveLaptops = get-adcomputer -Filter {lastLogonTimeStamp -lt $maxWorkstationTimeStampAsFileTime} -SearchBase $laptopOUDN -Properties description, lastLogonTimeStamp 


$billableComputers = $includedDesktops + $includedLaptops
$excludedComputers = $excludedDesktops + $excludedLaptops
$inactiveComputers = $inactiveDesktops + $inactiveLaptops
 
$totalComputers = $computersDesktops + $computerLaptops
 
Write-Host "Client Domain: $clientname"

Write-Host ""

Write-Host "Total Billable Users: $(($billableUsers | Measure-Object).Count)"
Write-Host "Total Excluded Users: $(($excludedUsers | Measure-Object).Count)"
Write-Host "Total Inactive Users: $(($inactiveUsers | Measure-Object).Count)"

Write-Host ""

Write-Host "Total Billable Computers: $(($billableComputers | Measure-Object).Count)"
Write-Host "Total Excluded Computers: $(($excludedComputers | Measure-Object).Count)"
Write-Host "Total Inactive Computers: $(($inactiveComputers | Measure-Object).Count)"

Write-Host "`n"
Write-Host "Below is a list of users counted. If any of these should not be included in future reports, please add '$excludeFromReportString' to the telephone>notes field of the user object"

Write-Host "Billable Users:"
$billableUsers | ft Name

Write-Host "Excluded Users:"
$excludedUsers | ft Name, info

Write-Host "Inactive Users:"
$inactiveUsers | ft Name, @{N='LastSeen';E={[DateTime]::FromFileTime($_.lastLogonTimeStamp)}}


Write-Host "Below is a list of computers counted. If any of these should not be included in future reports, please add '$excludeFromReportString' to the description field of the computer object"

Write-Host "Billable Computers:"
$billableComputers | ft Name

Write-Host "Excluded Computers:"
$excludedComputers | ft Name, description

Write-Host "Inactive Computers:"
$inactiveComputers | ft Name, @{N='LastSeen';E={[DateTime]::FromFileTime($_.lastLogonTimeStamp)}}