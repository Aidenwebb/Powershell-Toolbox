Function Add-PathVariable {
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

function New-CertificateConfig{

param
(
    [parameter(mandatory=$true)]
    [string]$CountryName,
    [parameter(mandatory=$true)]
    $StateOrProvinceName,
    [parameter(mandatory=$true)]
    $LocalityName,
    [parameter(mandatory=$true)]
    [string]$OrganisationName,
    [parameter(mandatory=$true)]
    [string]$CommonName,
    [parameter(mandatory=$true)]
    [array]$SubjectAlternativeNames,
    [parameter(mandatory=$true)]
    [string]$OutputFilePath
)

$certconfig = @"
prompt = no
[ req ]
default_bits       = 2048
distinguished_name = req_distinguished_name
req_extensions     = req_ext
[ req_distinguished_name ]
countryName                 = $CountryName
stateOrProvinceName         = $StateOrProvinceName
localityName               = $LocalityName
organizationName           = $OrganisationName
commonName                 = $CommonName
[ req_ext ]
subjectAltName = @alt_names
[alt_names]
"@


for ($i=0; $i -lt $SubjectAlternativeNames.length; $i++) {
	#Write-Host $SubjectAlternativeNames[$i]
    
    $certconfig += "`n" # New Line
    $certconfig += "DNS.$($i+1) = $($SubjectAlternativeNames[$i])"
}

#$certconfig | Out-File $OutputFilePath -Encoding utf8NoBOM

$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
[System.IO.File]::WriteAllLines($OutputFilePath, $certconfig, $Utf8NoBomEncoding)

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

function New-CsrRsaCnfPackage{

param
(
    [parameter(mandatory=$true)]
    [string]$CountryName,
    [parameter(mandatory=$true)]
    $StateOrProvinceName,
    [parameter(mandatory=$true)]
    $LocalityName,
    [parameter(mandatory=$true)]
    [string]$OrganisationName,
    [parameter(mandatory=$true)]
    [string]$CommonName,
    [parameter(mandatory=$true)]
    [array]$SubjectAlternativeNames,
    [parameter(mandatory=$true)]
    [array]$OutputDirectory
)

    New-PrivateKey -OutputFilePath "$OutputDirectory\$CommonName.key"
    New-CertificateConfig -CountryName $CountryName `
        -StateOrProvinceName $StateOrProvinceName `
        -LocalityName $LocalityName `
        -OrganisationName $OrganisationName `
        -CommonName $CommonName `
        -SubjectAlternativeNames $SubjectAlternativeNames `
        -OutputFilePath "$OutputDirectory\$CommonName.cnf"
    New-CSR -RSAKeyPath "$OutputDirectory\$CommonName.key" -ConfigPath "$OutputDirectory\$CommonName.cnf" -OutputFilePath "$OutputDirectory\$CommonName.csr"        
}