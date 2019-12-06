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
            $ACLMiddle = "LONGPATH_$($RootName)_.._$($CleanedPathSplit[-1])_$($CleanedPathSplit[-2])"
            if ($ACLMiddle -gt 42){
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

    New-ADGroup -GroupCategory Security -GroupScope DomainLocal -Name $ACLName -Description $ACLDescription -Path $TargetOUDistinguishedName
    Set-ADGroup -Identity $ACLName -Replace @{info="$ACLNotes"}
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
        Write-Verbose "ACL group $ACLName created"
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
        Write-Verbose "Granting $ACLGroupFormatted with $ACLType Rights to $FullFolderPath"
        $CurrentFolderACL = Get-Acl -Path $FullFolderPath
        $CurrentFolderACL.SetAccessRule($AccessRule)
        $CurrentFolderACL | Set-ACL -Path $FullFolderPath
        Write-Verbose "Permissions Granted Successfully"
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
            if(-Not ($_ | Test-OUExists))
            {
                throw "OU does not exist - $($_)"
            }
        })]
        [Parameter(Mandatory=$true,
        Position=1,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [String]
        $StaffGroup_OU_DistinguishedName
        ,

        [ValidateScript({
            if(-Not ($_ | Test-OUExists))
            {
                throw "OU does not exist - $($_)"
            }
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
    )

    # Check if folder exists
    $FolderExists = Test-Path $FullFolderPath -PathType Container

    # Check if Staff Target OU exists
    $StaffOUExists = Test-OUExists -OUDistinguishedName $StaffGroup_OU_DistinguishedName
    # Check if Staff Group already exists
    $StaffADGroup = Get-ADGroup -SearchBase $StaffGroup_OU_DistinguishedName -Filter {(Name -eq $StaffGroup_OU_DistinguishedName) -and (GroupCategory -eq "Security")}
            #   If group doesn't exist, create it

    # Check if ACL Target OU exists
    $ACLOUExists = Test-OUExists -OUDistinguishedName $ACL_OU_DistinguishedName

    # Check if ACL set exists 
    $ACLTypeSet = ("Traverse","ReadOnly","ReadWrite","FullControl")
    foreach ($ACLType in $ACLTypeSet)
    {
        Write-Verbose "Getting $ACLType Group"
        $ACLName = New-ACLName -FullFolderPath $FullFolderPath -ACLLevel $ACLType
        $ACLGroup = Get-ADGroup -SearchBase $ACL_OU_DistinguishedName -Filter {(Name -eq $ACLName) -and (GroupCategory -eq "Security")}
        If (-Not ($ACLGroup)){
            New-ACL -ACLName $ACLName -FullFolderPath $FullFolderPath -ACLRights $ACLType -TargetOUDistinguishedName $ACL_OU_DistinguishedName
        }
    }

    # Check if relevant ACLs already exists on folder 
            # If false - create a set
            Set-ACLsOnFolder -FullFolderPath $FullFolderPath

    # Add relevant ACL to the Staff group

    # Check each folder upstream of target folder
            # Check if ACL set already exists on folder, particularly Traverse.
                # If false, create a set
            # Add Traverse ACL to the Staff group

    <#
    Example output:
    Staff Target OU Exists - OU=Standard,OU=Staff,OU=Security Groups,OU=Accounts,DC=testdomain,DC=local
    Staff Target OU contains Staff Group named "HR Staff" / Staff Group created in Target OU
    ACL Target OU Exists - OU=Standard,OU=Resources,OU=Security Groups,OU=Accounts,DC=testdomain,DC=local
    ACL Target OU contains ACLs for folder: / ACL's created for folder in Target OU
      - ACL_FolderName_T
      - ACL_FolderName_R
      - ACL_FolderName_RW
      - ACL_FolderName_FC
    Applied ACL's to folder
      - ACL_FolderName_T - Traverse - The Folder Only
      - ACL_FolderName_R - Read Only - This Folder, Subfolders and Files
      - ACL_FolderName_RW - Modify - This Folder, Subfolders and Files
      - ACL_FolderName_FC - Full Control - This Folder, Subfolders and Files
    Added Staff Group as a member of Modify ACL
    Checking upstream folders.
    Folder A - 
        ACL Target OU contains ACLs for folder: / ACL's created for folder in Target OU
            - ETC
        Folder has ACL's applied
            - ETC
        Added Staff Group as a member of Traverse ACL
    Folder B - 
        ACL Target OU contains ACLs for folder: / ACL's created for folder in Target OU
            - ETC
        Folder has ACL's applied
            - ETC
        Added Staff Group as a member of Traverse ACL
    #>

}