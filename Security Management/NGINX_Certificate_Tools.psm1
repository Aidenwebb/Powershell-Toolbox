function Update-Certificate{

    param
    (
        [parameter(mandatory=$true)]
        [string]$DNSName,
        [parameter(mandatory=$true)]
        [string]$InputCertificatePath,
        [parameter(mandatory=$true)]
        [string]$InputKeyPath,
        [parameter(mandatory=$true)]
        [string]$TargetLocation,
        [parameter(mandatory=$true)]
        [string]$BackupLocation,
        [string]$CrtName="$DNSName-crt.pem",
        [string]$KeyName="$DNSName-key.pem"
    )

    # Backup existing files
    Copy-Item -Path $TargetLocation -Destination "$BackupLocation\$(Get-Date -Format yyyy-MM-dd)" -Recurse -Force

    # Copy new certs in to PBX
    Copy-Item -Path $InputCertificatePath -Destination "$TargetLocation\$CrtName"
    Copy-Item -Path $InputKeyPath -Destination "$TargetLocation\$KeyName"

    # Restart nginx
    Restart-Service nginx
}