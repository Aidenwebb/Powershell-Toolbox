# This module contains a conflicting command for Get-PFXCertificate. It's recommended that it is imported using a prefix
# Import-Module <module> -Prefix ict

function Get-BestCertificate
{

    [cmdletbinding()]

        param
    (
        [parameter(
            ValueFromPipeline = $true
            )]
        [string[]]$Directory='.',
        [parameter(mandatory=$true)]
        [string]$DnsName,
        [parameter(mandatory=$true)]
        [string]$PfxPassword
    )

    BEGIN {}

    PROCESS
    {
        # Get list of valid certificates
        $validcerts = Get-ValidCertificates -DnsName $DnsName -PfxPassword $PfxPassword -Directory $Directory

        # Get the certificate from the list that has the longest time before expiry
        $validcerts = $validcerts | Sort-Object NotAfter -Descending
        $targetcert = $validcerts[0]

        $targetcert
    }

    END {}

}

function Get-PFXCertificate{
[cmdletbinding()]

param
(
    [parameter(
        mandatory=$true, 
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true
        )]
    [Alias('FullName')]
    [string[]]$File,
    [parameter(mandatory=$true)]
    [string]$Password


)

BEGIN{}

PROCESS {
        
        foreach ($FileItem in $File)
            {

            if (Test-Path -Path $FileItem)
            {

                Write-Host $FileItem
                #Write-Host $Password
                $pfxfile = Get-Item $FileItem
                $pfxfile| fl *

                $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
                $cert.Import($pfxfile,$Password,'DefaultKeySet')

                $cert | Add-Member -NotePropertyName FilePath -NotePropertyValue $pfxfile.FullName
                $cert
            }
            else
            {
                Write-Error "Cannot find file: $FileItem"
            }
        }
}

END {}
}

function Get-ValidCertificates{

    [cmdletbinding()]

        param
    (
        [parameter(
            ValueFromPipeline = $true
            )]
        [string[]]$Directory='.',
        [parameter(mandatory=$true)]
        [string]$DnsName,
        [parameter(mandatory=$true)]
        [string]$PfxPassword
    )

    BEGIN {}

    PROCESS
    {
        foreach ($folder in $Directory)
        {
            if (Test-Path -Path $folder)
            {
                Get-ChildItem -Path $folder -File -Filter *.pfx | Get-PFXCertificate -Password $PfxPassword | Where-Object {($_.DnsNameList -contains $DnsName) -and ($_.NotBefore -lt (Get-Date)) -and ($_.NotAfter -gt (Get-Date))}
            }
            else
            {
                Write-Error "Cannot find file: $folder"
            }
        }
    }

    END{}
}

function Import-BestCertificate
{

        [cmdletbinding()]

        param
    (
        [parameter(
            ValueFromPipeline = $true
            )]
        [string[]]$Directory='.',
        [parameter(mandatory=$true)]
        [string]$DnsName,
        [parameter(mandatory=$true)]
        [string]$PfxPassword
    )

    $bestcert = Get-BestCertificate -DnsName $DnsName -PfxPassword $PfxPassword -Directory $Directory
    $securecertpassword = ConvertTo-SecureString -String $PfxPassword -AsPlainText -Force
    Import-PfxCertificate -FilePath $bestcert.FilePath -Password $securecertpassword -CertStoreLocation Cert:\LocalMachine\WebHosting

}

function Bind-CertificateToHTTPS{

    param
    (
        [parameter(mandatory=$true)]
        [string]$CertThumbprint,
        [string]$CertStore='WebHosting'
    )

    $httpsbinding = Get-WebBinding -Protocol https

    $httpsbinding.AddSslCertificate($CertThumbprint, $CertStore)


}