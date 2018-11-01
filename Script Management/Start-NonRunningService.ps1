function Start-NonRunningService ([string]$ServiceName)
{
    <#
        .SYNOPSIS
            Checks if a service is running and if it isn't, starts the service.
        .EXAMPLE
            Start-NonRunningService -ServiceName BITS

            Description
            -----------
            Checks if a service is running and if it isn't, starts the service.
    #>


    #Check if user is administrator
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) -eq $false)
    {
        Throw "This function must be run as an Administrator"
    }

    else
    {

        $arrService = Get-Service -Name $ServiceName
 
        while ($arrService.Status -ne 'Running')
        {
 
           Start-Service $ServiceName
           write-host $arrService.status
           write-host 'Service starting'
           Start-Sleep -seconds 60
           $arrService.Refresh()
           if ($arrService.Status -eq 'Running')
           {
               Write-Host 'Service is now Running'
           }
 
        } 

    }
}