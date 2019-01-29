### Clears temporary files, Recycle Bins and OSTs which are older than the day threshold set below. Designed to run on an RDS / File server as administrator.

# Parameters
param
(
    [Parameter()]
    [string]$targetDriveLetter = "C", # The target drive letter
    [Parameter()] 
    [ValidateRange(0, [int]::MaxValue)] # Minimum 0 as trying to delete items from the future causes problems 
    [int]$targetObjectsModifiedAge = 60 # Target files with a last modified date older than this number of days
)

### Output script parameters so if there's a problem we can check for obvious mistakes.

Write-Host "---DEBUG---"
Write-Host "---Version 0.0.1---"
Write-Host "Running as: $(whoami)"
Write-Host "Args Count: $($args.Count)"
Write-Host "Args Count: $($args.Count)"
Write-Host "All passed args:"
$args
Write-Host "Parameters Count: $($PsBoundParameters.Count)"
Write-Host "All passed parameters:"
$PsBoundParameters
Write-Host "--------------------------------------"
Write-Host ""

$targetDrivePath = $targetDriveLetter + ":"

$usersFolder = $targetDrivePath + "\Users\"

$freespace = (Get-PSDrive $targetDriveLetter).Free 


# To add new paths, filetype must be in the format ".ext" or ".*" if extension agnostic.

$userTemporaryFiles = @(
    [pscustomobject]@{Path='\AppData\Local\Temp\'; Filetype=".*"},
    [pscustomobject]@{Path='\AppData\Local\'; Filetype=".tmp"},
    [pscustomobject]@{Path='\AppData\Local\Temporary Internet Files\'; Filetype=".*"},
    [pscustomobject]@{Path='\Downloads\'; Filetype=".*"},
    [pscustomobject]@{Path='\AppData\Local\Google\Chrome\User Data\Default\Cache\'; Filetype=".*"},
    [pscustomobject]@{Path='\AppData\Local\Google\Chrome\User Data\Default\Media Cache\'; Filetype=".*"},
    [pscustomobject]@{Path='\AppData\Local\Google\Chrome\User Data\Default\old_Cache_000\'; Filetype=".*"},
    [pscustomobject]@{Path='\AppData\Local\Microsoft\Office\15.0\Lync\Tracing\'; Filetype=".*"},
    [pscustomobject]@{Path='\AppData\Local\Microsoft\Office\14.0\OfficeFileCache\'; Filetype=".*"},
    [pscustomobject]@{Path='\Tracing\'; Filetype=".*"},
    [pscustomobject]@{Path='\AppData\Local\WebEx\wbxcache\*'; Filetype=".*"},
    [pscustomobject]@{Path='\AppData\Local\Microsoft\Outlook\'; Filetype=".ost"}
    )

$systemTemporaryFiles = @(
    [pscustomobject]@{Path='\$Recycle.Bin'; Filetype=".*"}
    )

# Check if User Path exists
If(Test-Path -Path $usersFolder)
{
    # Get all the folders within the user profiles folder
    $profileFolderPaths = (Get-ChildItem $usersFolder).FullName
    foreach ($profilePath in $profileFolderPaths)
    {
        Write-Host "Processing: $profilePath"

        # Test each of the temporary file paths against the user folder and if it exists, clean it up.
        foreach ($userTemporaryFile in $userTemporaryFiles)
        {
            $combinedPath = $profilePath + $userTemporaryFile.Path
            If(Test-Path -Path ($combinedPath))
            {
                Write-Host "$combinedPath exists: Clearing old data"
                Get-ChildItem  -Recurse -Force ($combinedPath)  | Where-Object { $_.Extension -match $userTemporaryFile.Filetype -and !$_.PSIsContainer -and $_.LastWriteTime -lt (Get-Date).AddDays(-$targetObjectsModifiedAge) } | RM -Force
            } Else {
                Write-Host "$combinedPath does not exist: Skipping"
            } 
            
        }

    }

}

# Check if System Paths exist and if it exists, clean it up.
foreach ($systemTemporaryFile in $systemTemporaryFiles)
        {
            $combinedPath = $targetDrivePath + $systemTemporaryFile.Path
            If(Test-Path -Path ($combinedPath))
            {
                Write-Host "$combinedPath exists: Clearing old data"
                Get-ChildItem  -Recurse -Force ($combinedPath)  | Where-Object { $_.Extension -match $systemTemporaryFile.Filetype -and !$_.PSIsContainer -and $_.LastWriteTime -lt (Get-Date).AddDays(-$targetObjectsModifiedAge) } | RM -Force
            } Else {
                Write-Host "$combinedPath does not exist: Skipping"
            } 
            
        }

Write-host ("Recovered GBs: " + (((Get-PSDrive $targetDriveLetter).Free - $freespace) / 1GB))