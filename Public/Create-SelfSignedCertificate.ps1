# Function to create a self-signed certificate
function Create-SelfSignedCertificate {
    param (
        [string]$certificateName
    )
    Write-Host "Creating self-signed certificate for $certificateName"
    $cert = New-SelfSignedCertificate -Subject "CN=$certificateName" -CertStoreLocation "cert:\CurrentUser\My" -KeyExportPolicy Exportable -KeySpec Signature
    return $cert
}