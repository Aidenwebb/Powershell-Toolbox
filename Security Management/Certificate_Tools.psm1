﻿Function Add-PathVariable {
    param (
        [string]$addPath
    )
    if (Test-Path $addPath){
        $regexAddPath = [regex]::Escape($addPath)
        $arrPath = $env:Path -split ';' | Where-Object {$_ -notMatch 
"^$regexAddPath\\?"}
        $env:Path = ($arrPath + $addPath) -join ';'
    } else {
        Throw "'$addPath' is not a valid path."
    }
}

function Install-Choco{
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
}
# Install Choco

function Install-OpenSSL{

choco install openssl.light -y
Add-PathVariable -addPath "C:\Program Files\OpenSSL\bin"

}

function New-PrivateKey{

param
(
    [parameter(mandatory=$true)]
    [string]$OutputFilePath,
    [string]$OpenSSLEXEPath

)


If ($OpenSSLEXEPath){
    & $OpenSSLEXEPath genrsa -out $OutputFilePath 2048
    }

Else{

    openssl genrsa -out $OutputFilePath
    }
}

function New-CSR
{

param
(
    [parameter(mandatory=$true)]
    [string]$RSAKeyPath,
    [parameter(mandatory=$true)]
    [string]$ConfigPath,
    [parameter(mandatory=$true)]
    [string]$OutputFilePath

)


If ($OpenSSLEXEPath){
    & $OpenSSLEXEPath req -new -out $OutputFilePath -key $RSAKeyPath -config $ConfigPath
    }

Else{
    openssl req -new -out $OutputFilePath -key $RSAKeyPath -config $ConfigPath
    }
}

function ConvertTo-PFX{

param
(
    [parameter(mandatory=$true)]
    [string]$InputCertificatePath,
    [parameter(mandatory=$true)]
    [string]$PrivateKeyPath,
    [parameter(mandatory=$true)]
    [string]$OutputPath,
    [parameter(mandatory=$true)]
    [string]$PFXPassword,
    [string]$OpenSSLEXEPath

)

If ($OpenSSLEXEPath){
Write-Host Path: $OpenSSLEXEPath


. $OpenSSLEXEPath pkcs12 -export -out $($OutputPath) -inkey $($PrivateKeyPath) -in $($InputCertificatePath) -password "pass:$PFXPassword"
}
Else{

    openssl pkcs12 -export -out $($OutputPath) -inkey $($PrivateKeyPath) -in $($InputCertificatePath) -password "pass:$PFXPassword"
    }


}


function ConvertTo-PEM{

param
(
    [parameter(mandatory=$true)]
    [string]$InputCertificatePath,
    [parameter(mandatory=$true)]
    [string]$PFXPassword,
    [parameter(mandatory=$true)]
    [string]$OutputCrtPath,
    [parameter(mandatory=$true)]
    [string]$OutputKeyPath,
    [string]$OpenSSLEXEPath

)

If ($OpenSSLEXEPath){
Write-Host Path: $OpenSSLEXEPath


. $OpenSSLEXEPath pkcs12 -in $($InputCertificatePath) -password "pass:$PFXPassword" -nocerts -out $($OutputKeyPath) -nodes
. $OpenSSLEXEPath pkcs12 -in $($InputCertificatePath) -password "pass:$PFXPassword" -nokey -out $($OutputCrtPath) -nodes
}
Else{
    openssl $OpenSSLEXEPath pkcs12 -in $($InputCertificatePath) -passin "pass:$PFXPassword" -nocerts -out $($OutputKeyPath) -nodes
    openssl $OpenSSLEXEPath pkcs12 -in $($InputCertificatePath) -passin "pass:$PFXPassword" -nokeys -out $($OutputCrtPath) -nodes
    }


}