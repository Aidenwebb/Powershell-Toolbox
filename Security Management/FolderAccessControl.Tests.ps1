$module = Import-Module .\FolderAccessControl.psm1 -PassThru

InModuleScope $module.Name {
    Describe 'Get-PathDepth' {
        Context 'No Mocking'{
            It 'Fails without mocking'{
                {Get-PathDepth -Path FakeDrive:\InvalidFolderPath | Should -Throw "Cannot validate argument on parameter 'Path'. Folder does not exist"}
            }
        }
        Context 'Invalid Path specified'{
            Mock Test-Path {return $false}
            It 'Fails if the folder path does not exist'{
                {Get-PathDepth -Path TestDrive:\InvalidFolderPath} | Should -Throw "Cannot validate argument on parameter 'Path'. Folder does not exist"
            }
        }
        Context 'Valid Path specified'{
            Mock Test-Path {return $true}
            It 'Test Path mock works'{
                Test-Path -Path "FakeDrive:\" | Should -Be $true
            }
            It 'Returns a depth of 0 for a root level volume directory'{
                Get-PathDepth -Path "FakeDrive:\" | Should -Be 0
            }
            It 'Returns a depth of 0 for a root DFS directory'{
                Get-PathDepth -Path "\\testdomain.local\rootfolder\" | Should -Be 0
            }
            It 'Returns a depth of 1 for a 1st level volume directory'{
                Get-PathDepth -Path "FakeDrive:\1stlevel" | Should -Be 1
            }
            It 'Returns a depth of 1 for a 1st level DFS directory'{
                Get-PathDepth -Path "\\testdomain.local\rootfolder\1stlevel" | Should -Be 1
            }
            It 'Returns a depth of 10 for a 10th level volume directory'{
                Get-PathDepth -Path "FakeDrive:\1stlevel\2ndlevel\3rd\4th\5th\6th\7th\8th\9th\10th" | Should -Be 10
            }
            It 'Returns a depth of 10 for a 10th level DFS directory'{
                Get-PathDepth -Path "\\testdomain.local\rootfolder\1stlevel\2ndlevel\3rd\4th\5th\6th\7th\8th\9th\10th" | Should -Be 10
            }
        }
    }
    Describe 'Remove-InvalidFileNameChars'{
        Context 'InvalidPathProvided'{
            $invalidChars = '"<>|*?\/'
            $InvalidPath = "C:\FakeFolder\chars-$($invalidChars)-endchars"
            It 'Clears invalid characters from a path'{
                Remove-InvalidFileNameChars -Name $InvalidPath | Should -Be "CFakeFolderchars--endchars"
            }
        }
    }

    Describe 'Clean-FolderPath'{
        Context 'FolderPaths'{
            It 'Removes illegal characters, spaces, colons, slashes and duplicate underscores from path '{
                Clean-FolderPath -Path "C:\testpath\test_path\test__path\testpath_\_\_testpath" | Should -Be "C_testpath_test_path_test_path_testpath_testpath"
            }
        }
    }


    Describe 'Get-RootName'{
        Context 'UNCPath'{

            Mock Get-Item {
                return @{
                    PSPath = "Microsoft.PowerShell.Core\FileSystem::\\testdomain.local\mgt\sync\tools"
                    PSParentPath = "Microsoft.PowerShell.Core\FileSystem::\\testdomain.local\mgt\sync"
                    PSChildName = "tools"
                    PSProvider = "Microsoft.PowerShell.Core\FileSystem"
                    PSIsContainer = $True
                    Mode = "d-----"
                    BaseName = "tools"
                    Target = $null
                    LinkType = $null
                    Name = "tools"
                    FullName = "\\testdomain.local\mgt\sync\tools"
                    Parent = "sync"
                    Exists = $true
                    Root = "\\testdomain.local\mgt"
                    Extension = $null
                    CreationTime = "16/04/2015 02:20:31"
                    CreationTimeUtc = "16/04/2015 01:20:31"
                    LastAccessTime = "22/11/2019 14:01:28"
                    LastAccessTimeUtc = "22/11/2019 14:01:28"
                    LastWriteTime = "22/11/2019 14:01:28"
                    LastWriteTimeUtc = "22/11/2019 14:01:28"
                    Attributes = "Directory"
                }
            }

            Mock Test-Path {return $true}
            It 'Should return the root share of a UNC path'{
                Get-RootName -Path "\\testdomain.local\mgt\sync\tools" | Should -Be "\\testdomain.local\mgt"
            }
        }
        Context 'LogicalDiskPath'{
            Mock Get-Item {
                return @{
                    PSPath = "Microsoft.PowerShell.Core\FileSystem::C:\temp\Active Directory\"
                    PSParentPath = "Microsoft.PowerShell.Core\FileSystem::C:\temp"
                    PSChildName = "Active Directory"
                    PSDrive = "C"
                    PSProvider = "Microsoft.PowerShell.Core\FileSystem"
                    PSIsContainer = $True
                    Mode = "d-----"
                    BaseName = "Active Directory"
                    Target = "{C:\Temp\Active Directory}"
                    LinkType = $null
                    Name = "Active Directory"
                    FullName = "C:\temp\Active Directory\"
                    Parent = "temp"
                    Exists = $true
                    Root = "C:\"
                    Extension = $null
                    CreationTime = "16/04/2015 02:20:31"
                    CreationTimeUtc = "16/04/2015 01:20:31"
                    LastAccessTime = "22/11/2019 14:01:28"
                    LastAccessTimeUtc = "22/11/2019 14:01:28"
                    LastWriteTime = "22/11/2019 14:01:28"
                    LastWriteTimeUtc = "22/11/2019 14:01:28"
                    Attributes = "Directory"
                }
            }
            Mock Test-Path {return $true}
            It 'Should return the volume name of a LogicalDisk path'{
                Get-RootName -Path "C:\temp\Active Directory\" | Should -Be "C:\"
            }
        }
    }
    Describe 'New-ACLName'{
        Context 'LongFolderPath'{
            Mock Test-Path {return $true}
            Mock Test-Path {return $false} -ParameterFilter {$PathType -eq "Leaf"}
            Mock Get-RootName {return "FakeDrive:\"}
            $longFolderPath = "FakeDrive:\1stlevel\2ndlevel\3rd\4th\5th\6th\7th\8th\9th\10th\reallyreallylongfolderpath\farlongerthan64character"
            It 'Does not return a CN of over 64 characters when fed a long folder path'{
                (New-ACLName -FullFolderPath $longFolderPath -ACLLevel FullControl).length | Should -BeLessThan 64
            }
            It 'Returns an ACL Starting with ACL_LONGPATH_'{
                New-ACLName -FullFolderPath $longFolderPath -ACLLevel FullControl | Should -Match "^ACL_LONGPATH\S+_FC$"
            }
        }
        Context 'FolderPath Less than 64 characters long - LogicalDisk'{
            Mock Test-Path {return $true}
            Mock Test-Path {return $false} -ParameterFilter {$PathType -eq "Leaf"}
            Mock Get-RootName {return "FakeDrive:\"}
            $FolderPath = "FakeDrive:\1stlevel\2ndlevel"
            It 'Returns an ACL name ending in FC for Full Control' {
                New-ACLName -FullFolderPath $FolderPath -ACLLEvel FullControl | Should -Match "^ACL_\S+_FC$"
            }
            It 'Returns an ACL name ending in RW for ReadWrite' {
                New-ACLName -FullFolderPath $FolderPath -ACLLEvel ReadWrite | Should -Match "^ACL_\S+_RW$"
            }
            It 'Returns an ACL name ending in R for ReadOnly' {
                New-ACLName -FullFolderPath $FolderPath -ACLLEvel ReadOnly | Should -Match "^ACL_\S+_R$"
            }
            It 'Returns an ACL name ending in T for Traverse' {
                New-ACLName -FullFolderPath $FolderPath -ACLLEvel Traverse | Should -Match "^ACL_\S+_T$"
            }
            It 'Returns ACL_ROOT for ACLs applied directly to the root volume'{
                New-ACLName -FullFolderPath FakeDrive:\ -ACLLEvel Traverse | Should -Match "^ACL_ROOT_FakeDrive_T$"
            }
        }
        Context 'FolderPath Less than 64 characters long - UNC Path'{
            Mock Test-Path {return $true}
            Mock Test-Path {return $false} -ParameterFilter {$PathType -eq "Leaf"}
            Mock Get-RootName {return "\\testdomain.local\rootshare"}
            $FolderPath = "\\testdomain.local\rootshare\rootshare\1stlevel\2ndlevel"
            It 'Returns an ACL name ending in FC for Full Control' {
                New-ACLName -FullFolderPath $FolderPath -ACLLEvel FullControl | Should -Match "^ACL\S+FC$"
            }
            It 'Returns an ACL name ending in RW for ReadWrite' {
                New-ACLName -FullFolderPath $FolderPath -ACLLEvel ReadWrite | Should -Match "^ACL\S+RW$"
            }
            It 'Returns an ACL name ending in R for ReadOnly' {
                New-ACLName -FullFolderPath $FolderPath -ACLLEvel ReadOnly | Should -Match "^ACL\S+R$"
            }
            It 'Returns an ACL name ending in T for Traverse' {
                New-ACLName -FullFolderPath $FolderPath -ACLLEvel Traverse | Should -Match "^ACL\S+T$"
            }
            It 'Returns ACL_ROOT for ACLs applied directly to the root volume'{
                New-ACLName -FullFolderPath "\\testdomain.local\rootshare" -ACLLEvel Traverse | Should -Match "^ACL_ROOT_testdomain.local_rootshare_T$"
            }
        }
    }
}