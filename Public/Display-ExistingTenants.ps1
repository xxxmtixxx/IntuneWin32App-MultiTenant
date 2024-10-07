# Function to display existing tenants from the CSV
function Display-ExistingTenants {
    if (Test-Path $csvPathCred) {
        $existingCredentials = Import-Csv -Path $csvPathCred
        Write-Host ""
        Write-Host "Existing tenants in the CSV file:"
        foreach ($credential in $existingCredentials) {
            Write-Host "Tenant Name: $($credential.TenantName), Domain: $($credential.Domain)"
        }
    } else {
        Write-Host "No existing tenants found in the CSV file."
    }
}