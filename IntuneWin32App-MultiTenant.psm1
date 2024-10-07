# IntuneWin32App-MultiTenant.psm1

# Dot source the public functions
. $PSScriptRoot\Public\Display-ExistingTenants.ps1
. $PSScriptRoot\Public\Check-SecurityGroupExists.ps1
. $PSScriptRoot\Public\Create-SelfSignedCertificate.ps1
. $PSScriptRoot\Public\Remove-ExistingApplication.ps1
. $PSScriptRoot\Public\Process-Application.ps1

# Export the public functions
Export-ModuleMember -Function 'Display-ExistingTenants', 'Check-SecurityGroupExists', 'Create-SelfSignedCertificate', 'Remove-ExistingApplication', 'Process-Application'