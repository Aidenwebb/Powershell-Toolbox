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
        Calculate-PathDepth -Path $ParentPath -DepthCounter $DepthCounter
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

    $PathDepth = Get-PathDepth -Path $FullFolderPath
    
    
    $PathLeaf = Split-Path $FullFolderPath -Leaf

    Switch ($PathDepth)
    {
        0 {$ACLName = "ACL_VOLUME_$($PathLeaf)_$($ACLLevelSuffix)"}
        1 {$ACLName = "ACL_ROOT_$($PathLeaf)_$($ACLLevelSuffix)"}
        {$_ -ge 2} {
            $ParentLeaf = Split-Path (Split-Path $FullFolderPath -Parent) -Leaf
            $ACLName = "ACL_$($ParentLeaf)_$($PathLeaf)_$($ACLLevelSuffix)"
        }

    }

    
    #$ParentLeaf = Split-Path (Split-Path $FullFolderPath -Parent) -Leaf
    #$ACLName = "ACL_$($ParentLeaf)_$($PathLeaf)_$($ACLLevelSuffix)"

    return $ACLName.Replace(' ','_') | Remove-InvalidFileNameChars
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