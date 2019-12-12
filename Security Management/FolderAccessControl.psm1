Function Get-PathDepth {
    Param(
    [ValidateScript({
        if( -Not ($_ | Test-Path )){
            throw "Folder does not exist"
        }
        return $true
        })]
    [String]
    $Path,

    [Int]
    $DepthCounter=0
    )

    $ParentPath = Split-Path $Path -Parent

    if($ParentPath)
    {
        $DepthCounter++
        Get-PathDepth -Path $ParentPath -DepthCounter $DepthCounter
    }
    
    else 
    {
        return $DepthCounter
    }
}


Function Remove-InvalidFileNameChars {
  param(
    [Parameter(Mandatory=$true,
      Position=0,
      ValueFromPipeline=$true,
      ValueFromPipelineByPropertyName=$true)]
    [String]$Name
  )

  $invalidChars = [IO.Path]::GetInvalidFileNameChars() -join ''
  $re = "[{0}]" -f [RegEx]::Escape($invalidChars)
  return ($Name -replace $re)
}

Function Get-RootName {
    Param(
    [ValidateScript({
        if( -Not ($_ | Test-Path )){
            throw "Folder does not exist"
        }
        return $true
        })]
    [String]
    $Path
    )
    
    return (Get-item -Path $Path).Root 
}

Function Clean-FolderPath{
    Param(
        [Parameter(Mandatory=$true,
        Position=0,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [String]
        $Path
    )
#replacing spaces with Blank, replacing \ with underscores, removing :, removing duplicate _'s, remove invalid characters

    # Remove :
    $CleanedPath = $Path.Replace(":","")
    # Remove Spaces
    $CleanedPath = $Path.Replace(" ","")
    #Replace \ with _
    $CleanedPath = $CleanedPath.Replace("\","_")
    # Remove invalid characters
    $CleanedPath = $CleanedPath | Remove-InvalidFileNameChars
    #Remove duplicate _'s
    return $CleanedPath -replace "(?m)_(?=_|$)" 
}

function New-ACLName{

    Param(
    [ValidateScript({
        if( -Not ($_ | Test-Path )){
            throw "Folder does not exist"
        }
        if($_ | Test-Path -PathType Leaf){
                throw "The Path argument must be a folder. File paths are not allowed."
        }

        return $true
        })]
    [String]
    $FullFolderPath
    , 
    
    [ValidateSet("Traverse","ReadOnly","ReadWrite","FullControl")]
    [String]
    $ACLLevel
    )
    
    Switch ($ACLLevel)
    {
        "Traverse" { $ACLLevelSuffix = "T"}
        "ReadOnly" { $ACLLevelSuffix = "R"}
        "ReadWrite" { $ACLLevelSuffix = "RW"}
        "FullControl" { $ACLLevelSuffix = "FC"}
    }

    $ACLPrefix = "ACL"

    $PathDepth = Get-PathDepth -Path $FullFolderPath
    
    If ($FullFolderPath.Length -ge 44){
        $LongPath = $true
    }
    else {
        $LongPath = $false
    }

    $RootName = Get-RootName -Path $FullFolderPath | Clean-FolderPath

    $CleanedPath = Clean-FolderPath $FullFolderPath

    # If the path depth is 0, use ROOT ACL name
    If ($PathDepth -eq 0){
        $ACLMiddle = "ROOT_$($RootName)"
    }

    elseif ($PathDepth -ge 1 ) {
        

        # If path depth is over 1, and it is a long path
        # Use root + .. + last 2 folders of path, replacing spaces with Blank, replacing \ with underscores, removing :, removing duplicate _'s, remove invalid characters
        if ($LongPath) {
            $CleanedPathSplit = $CleanedPath.Split("_")
            $ACLMiddle = "LONGPATH_$($RootName)_DEPTH-$($PathDepth)_$($CleanedPathSplit[-1])"
            if ($ACLMiddle.Length -gt 42){
                $ACLMiddle = "$($ACLMiddle.Substring(0, 42)).."
            }


        }

        else {
            $ACLMiddle = "$($CleanedPath)"
        }
    }   

        # If path depth is over 1, and it is not a long path
        # Use full file path, replacing spaces with Blank, replacing \ with underscores, removing :, removing duplicate _'s, remove invalid characters
    else {
        throw "Something Broke"
    }

    $ACLName = "$($ACLPrefix)_$($ACLMiddle)_$($ACLLevelSuffix)"

    return $ACLName -replace "(?m)_(?=_|$)"
}
    
function New-ACL{
    
    Param(
        [String]
        $ACLName
        ,
        [String]
        $FullFolderPath, 

        [ValidateSet("Traverse","ReadOnly","ReadWrite","FullControl")]
        [String]
        $ACLRights, 

        [String]
        $TargetOUDistinguishedName
    )
    
    Switch ($ACLRights)
    {
        "Traverse" { $ACLDescription = "Users in this group will have access to view folders in $($FullFolderPath)"}
        "ReadOnly" { $ACLDescription = "Users in this group will have access to read files and folders in $($FullFolderPath)"}
        "ReadWrite" { $ACLDescription = "Users in this group will have access to read and write files and folders in $($FullFolderPath)"}
        "FullControl" { $ACLDescription = "Users in this group will have full access to files and folders in $($FullFolderPath)"}
    }

    $ACLNotes = @"
ACL Created from $env:COMPUTERNAME at $(Get-Date -Format "yyyy/MM/dd HH:mm")
$ACLRights Access - $FullFolderPath
"@

    # Check if group already exists
    $ACLGroup = Get-ADGroup -SearchBase $TargetOUDistinguishedName -Filter {(Name -eq $ACLName) -and (GroupCategory -eq "Security")}
    If ($ACLGroup){
        Write-Verbose -Message "ACL $($ACLName) already exists - skipped creation."
    }
    elseif (-Not ($ACLGroup)) {
        Write-Verbose "$ACLType Group not found - Creating $ACLName"
        New-ADGroup -GroupCategory Security -GroupScope DomainLocal -Name $ACLName -Description $ACLDescription -Path $TargetOUDistinguishedName
        Set-ADGroup -Identity $ACLName -Replace @{info="$ACLNotes"}
        Write-Verbose "$ACLType group $ACLName Created"
    }
    else {
        throw "Finding or creating the $($ACLName) ACL group failed"
    }

    return Get-ADGroup -SearchBase $TargetOUDistinguishedName -Filter {(Name -eq $ACLName) -and (GroupCategory -eq "Security")}    
}

function New-ACLSetFromFolderPath{
    [CmdletBinding()]
    Param(
        [ValidateScript({
        if( -Not ($_ | Test-Path )){
            throw "Folder does not exist"
        }
        if($_ | Test-Path -PathType Leaf){
                throw "The Path argument must be a folder. File paths are not allowed."
        }

        return $true
        })]
        [String]
        $FullFolderPath
        ,
    
    [String]
    $TargetOUDistinguishedName
    )

    $ACLTypeSet = ("Traverse","ReadOnly","ReadWrite","FullControl")
    Write-Verbose "Creating a set of ACL groups for $FullFolderPath"
    foreach ($ACLType in $ACLTypeSet)
    {
        $ACLName = New-ACLName -FullFolderPath $FullFolderPath -ACLLevel $ACLType
        Write-Verbose "Creating ACL group named $ACLName at $TargetOUDistinguishedName"
        New-ACL -ACLName $ACLName -FullFolderPath $FullFolderPath -ACLRights $ACLType -TargetOUDistinguishedName $TargetOUDistinguishedName
    }

}


function Set-ACLsOnFolder{
    [CmdletBinding()]
    Param(
        [ValidateScript({
        if( -Not ($_ | Test-Path )){
            throw "Folder does not exist"
        }
        if($_ | Test-Path -PathType Leaf){
                throw "The Path argument must be a folder. File paths are not allowed."
        }

        return $true
        })]
        [String]
        $FullFolderPath
    )
    Write-Verbose -Message "Setting ACL group permissions on folder - $FullFolderPath"
    $ACLTypeSet = ("Traverse","ReadOnly","ReadWrite","FullControl")

    foreach ($ACLType in $ACLTypeSet)
    {
        Write-Verbose "Getting $ACLType Group"
        $ACLName = New-ACLName -FullFolderPath $FullFolderPath -ACLLevel $ACLType
        $ACLGroup = Get-ADGroup -Identity $ACLName
        $ACLGroupFormatted = "$((($ACLGroup.DistinguishedName -split 'DC=')[1]).Replace(',',''))\$($ACLGroup.SamAccountName)"
        Write-Verbose "$ACLGroupFormatted found"
        

        Switch ($ACLType)
        {
            "Traverse" { $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($ACLGroupFormatted,"ReadAndExecute","None","None","Allow")} # Permissions granted to only this Folder. Traverse should not be inherited.
            "ReadOnly" { $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($ACLGroupFormatted,"ReadAndExecute","ObjectInherit,ContainerInherit","None","Allow")} # Permissions granted to this Folder, Subfolders and files
            "ReadWrite" { $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($ACLGroupFormatted,"Modify","ObjectInherit,ContainerInherit","None","Allow")} # Permissions granted to this Folder, Subfolders and files
            "FullControl" { $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($ACLGroupFormatted,"FullControl","ObjectInherit,ContainerInherit","None","Allow")} # Permissions granted to this Folder, Subfolders and files
        }
        Write-Verbose "Setting $ACLType rights to $FullFolderPath for $ACLGroupFormatted"
        $CurrentFolderACL = Get-Acl -Path $FullFolderPath
        $CurrentFolderACL.SetAccessRule($AccessRule)
        $CurrentFolderACL | Set-ACL -Path $FullFolderPath
        Write-Verbose "Permissions Set Successfully"
    }
}

Function Test-OUExists {
    param(    
        [Parameter(Mandatory=$true,
        Position=0,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [String]    
        $OUDistinguishedName    
        )

    return [adsi]::Exists("LDAP://$($OUDistinguishedName)")} 


Function Add-GroupAccessToFolder{
    
    <#
    .SYNOPSIS
        Grant an AD security group access to a folder using Role Based Access Control principals
    .DESCRIPTION
        This function takes a folder path and:
          - Creates a role/staff AD group to which users can be assigned (if one does not already exist)  
          - Creates a set of ACL AD security groups for the target folder and all upstream folders (if they do not already exist)
            - Traverse
            - ReadOnly
            - Read/Write
            - Full Control
          - Adds the staff group as a member of the appropriate target folder ACL group
          - Adds the staff group as a member of each upstream folders Traverse ACL group
          - If BreakInheritance parameter is set:
            - Creates an explicit folder permission on the folder granting System Full Control for the folder, subfolders and files
            - Breaks inheritance and clears inherited permissions if required.
    .NOTES
        Author : Aiden Arnkels-Webb - aiden.webb@gmail.com
        Requires: Powershell 5.1
    .EXAMPLE
        Add-GroupAccessToFolder `
          -StaffGroupName "Finance Auditors" `
          -StaffGroup_OU_DistinguishedName "OU=Standard,OU=Staff Roles,OU=Security Groups,OU=Accounts,DC=testdomain,DC=local" `
          -ACL_OU_DistinguishedName "OU=Standard,OU=ACLs,OU=Security Groups,OU=Accounts,DC=testdomain,DC=local" `
          -FullFolderPath "testdomain.local\dfs\Data\Finance" `
          -PermissionLevel ReadOnly `
          -BreakInheritance `
          -Verbose 


    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true,
        Position=0,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [String]
        $StaffGroupName
        ,

        [ValidateScript({
            if(-Not ($_ | Test-OUExists)) {
                throw "OU does not exist - $($_)"
            }
            return $true
        })]
        [Parameter(Mandatory=$true,
        Position=1,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [String]
        $StaffGroup_OU_DistinguishedName
        ,

        [ValidateScript({
            if(-Not ($_ | Test-OUExists)) {
                throw "OU does not exist - $($_)"
            }

            return $true
        })]
        [Parameter(Mandatory=$true,
        Position=2,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [String]
        $ACL_OU_DistinguishedName
        ,

        [ValidateScript({
            if( -Not ($_ | Test-Path )){
                throw "Folder does not exist"
            }
            if($_ | Test-Path -PathType Leaf){
                throw "The Path argument must be a folder. File paths are not allowed."
            }
    
            return $true
            })]
        [Parameter(Mandatory=$true,
        Position=4,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [String]
        $FullFolderPath
        ,

        [Parameter(Mandatory=$true,
        Position=5,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [ValidateSet("Traverse","ReadOnly","ReadWrite","FullControl")]
        [String]
        $PermissionLevel
        ,

        [Parameter(ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [Switch]
        $BreakInheritance
    )


    # Check if script has been run as Admin
    $AdminSession =  (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) 
    
    if (-Not ($AdminSession)){
        throw "This function may fail to complete leading to an inconsistent state if not run as an administrator. Please try again from an Admin Powershell session"
    }

    # Check if folder exists - Handled with parameter validation
    

    # Check if Staff Target OU exists - Handled with parameter validation
        
    # Check if Staff Group already exists
    $StaffADGroup = Get-ADGroup -SearchBase $StaffGroup_OU_DistinguishedName -Filter {(Name -eq $StaffGroupName) -and (GroupCategory -eq "Security")} -Properties *
    #   If group doesn't exist, create it
    If (-Not ($StaffADGroup)){
        Write-Verbose -Message "Staff group $($StaffGroupName) does not exist - Creating Global Security group"
        New-ADGroup -GroupCategory Security -GroupScope Global -Name $StaffGroupName -Path $StaffGroup_OU_DistinguishedName
        $StaffADGroup = Get-ADGroup -SearchBase $StaffGroup_OU_DistinguishedName -Filter {(Name -eq $StaffGroupName) -and (GroupCategory -eq "Security")} -Properties *
        
    }
    if ($StaffADGroup) {
        Write-Verbose -Message "Staff group $($StaffGroupName) found."
        Write-Verbose -Message "Adding permission note to $StaffADGroupName."

        $StaffGroupNotes = "$($StaffADGroup.info) `r`n $PermissionLevel access to $FullFolderPath"
        $StaffADGroup | Set-ADGroup -Replace @{info="$StaffGroupNotes"}

    }
    else {
        throw "Finding or creating the $($StaffGroupName) staff group failed"
    }

    # Check if ACL Target OU exists - Handled with parameter validation
    
    # Create missing ACL Groups on folder
    New-ACLSetFromFolderPath -FullFolderPath $FullFolderPath -TargetOUDistinguishedName $ACL_OU_DistinguishedName

    # Set relevant ACLs on folder 
            # If false - create a set
            Set-ACLsOnFolder -FullFolderPath $FullFolderPath

    # Add relevant ACL to the Staff group
        $ACLName = New-ACLName -FullFolderPath $FullFolderPath -ACLLevel $PermissionLevel
        Write-Verbose -Message "Added Staff Group $StaffGroupName as a member of $PermissionLevel ACL $TraverseACLName"
        $ACLGroup = Get-ADGroup -SearchBase $ACL_OU_DistinguishedName -Filter {(Name -eq $ACLName) -and (GroupCategory -eq "Security")}
        $ACLGroup | Add-ADGroupMember -Members $StaffGroupName


    # Check each folder upstream of target folder
    Write-Verbose -Message "Adding Traverse permissions for all folders upstream of $FullFolderPath"
    $PathDepth = Get-PathDepth -Path $FullFolderPath

    $ParentFolder = $FullFolderPath
    for ($depth=$PathDepth; $depth -gt 1; $depth--){
        Write-Verbose "Getting Parent of path - $ParentFolder"
        $ParentFolder = Split-Path -Path $ParentFolder -Parent
        Write-Verbose "Parent = $ParentFolder"

        # Create missing ACL Groups on folder
        New-ACLSetFromFolderPath -FullFolderPath $ParentFolder -TargetOUDistinguishedName $ACL_OU_DistinguishedName

        # Apply ACL's to folder
        Set-ACLsOnFolder -FullFolderPath $ParentFolder

        # Apply Traverse ACL to Staff Group
        
        $TraverseACLName = New-ACLName -FullFolderPath $ParentFolder -ACLLevel Traverse
        Write-Verbose -Message "Added Staff Group $StaffGroupName as a member of Traverse ACL $TraverseACLName"
        $TraverseACLGroup = Get-ADGroup -SearchBase $ACL_OU_DistinguishedName -Filter {(Name -eq $TraverseACLName) -and (GroupCategory -eq "Security")}
        $TraverseACLGroup | Add-ADGroupMember -Members $StaffGroupName
    }


    # Break Inheritance on the folder
    If ($BreakInheritance){
        Write-Verbose -Message "BreakInheritance flag is set. Ensuring System has explicit access to the folder before breaking inheritance"
        
        $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule("NT AUTHORITY\SYSTEM","FullControl","ObjectInherit,ContainerInherit","None","Allow") 

        $FolderAcl = Get-ACL -Path $FullFolderPath
        $Folderacl.SetAccessRule($AccessRule)
        $FolderAcl | Set-Acl -Path $FullFolderPath

        Write-Verbose -Message "Disabling inheritance and removing inherited permissions from $FullFolderPath"
        $FolderAcl = Get-ACL -Path $FullFolderPath
        $FolderAcl.SetAccessRuleProtection($true, $false)
        $FolderAcl | Set-Acl -Path $FullFolderPath
    }

    Write-Output "Add-GroupAccessToFolder complete"
    Write-Verbose -Message "Staff group located in OU: $StaffGroup_OU_DistinguishedName"
    Write-Verbose -Message "ACL groups located in OU: $ACL_OU_DistinguishedName"
    Write-Output "Please add staff to the $StaffGroupName group as required to grant $PermissionLevel access to $FullFolderPath"
}