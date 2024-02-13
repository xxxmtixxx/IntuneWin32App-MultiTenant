# Function to create a self-signed certificate with tenant information
function Create-SelfSignedCertificate {
    param (
        [string]$certificateName,
        [string]$tenantName # New parameter for tenant name
    )
    $subjectCN = "CN=$certificateName"
    if ($tenantName) {
        $subjectCN += " for Tenant: $tenantName" # Append tenant information to the CN
    }
    Write-Host "Creating self-signed certificate for $subjectCN"
    $cert = New-SelfSignedCertificate -Subject $subjectCN -CertStoreLocation "cert:\CurrentUser\My" -KeyExportPolicy Exportable -KeySpec Signature
    return $cert
}