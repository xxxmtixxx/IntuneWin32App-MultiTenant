# Define Win32Apps Folder
$Win32AppsFolder = "C:\IntuneMultiTenantManager\Win32Apps"

# Initialize the report array
$report = @()

# Check if the Win32Apps Folder exists, create it if it doesn't
if (-not (Test-Path -Path $Win32AppsFolder)) {
    New-Item -Path $Win32AppsFolder -ItemType Directory
    Write-Host "Created folder: $Win32AppsFolder"
} else {
    Write-Host "Folder already exists: $Win32AppsFolder"
}

# Define the CSV file path
$csvPathCred = Join-Path $PSScriptRoot 'Requirements\credentials.csv'
$csvPathApps = Join-Path $PSScriptRoot 'Requirements\applications.csv'

# Install the necessary modules
Install-Module AzureAD
Install-Module Microsoft.Graph.Authentication
Install-Module Microsoft.Graph.Groups
Install-Module IntuneWin32App
$documentsPath=[Environment]::GetFolderPath('MyDocuments');$url='https://github.com/xxxmtixxx/IntuneWin32App-MultiTenant/archive/refs/heads/main.zip';$moduleName='IntuneWin32App-MultiTenant';$modulePath=Join-Path $documentsPath 'WindowsPowerShell\Modules';$tempPath=Join-Path $env:TEMP ($moduleName+'.zip');Invoke-WebRequest -Uri $url -OutFile $tempPath;$tempDir='.'+$moduleName+'_temp';$extractPath=Join-Path $HOME $tempDir;Expand-Archive -Path $tempPath -DestinationPath $extractPath -Force;$sourceFolder=Join-Path $extractPath 'IntuneWin32App-MultiTenant-main';$destinationFolder=Join-Path $modulePath $moduleName;if (!(Test-Path $destinationFolder)) {New-Item -Path $destinationFolder -ItemType Directory | Out-Null};Copy-Item -Path "$sourceFolder\*" -Destination $destinationFolder -Recurse -Force

# Import the necessary modules
Import-Module AzureAD
Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.Groups
Import-Module IntuneWin32App
Import-Module IntuneWin32App-MultiTenant -DisableNameChecking

Write-Host ""
Write-Host "Starting script..."
Write-Host ""

# Ask the user for their choice
Write-Host "Please select an option:"
Write-Host "1: Add a new tenant"
Write-Host "2: Run against an existing tenant"
Write-Host "3: Run against all tenants"
Write-Host ""
$userChoice = Read-Host "Enter your choice (1, 2, or 3)"

# Initialize an empty array to hold the tenants to process
$currentTenant = @()

# Handle the user's choice
switch ($userChoice) {
    "1" {
        # Proceed to add a new tenant
        Write-Host "You have chosen to add a new tenant."
        # The rest of the script will proceed to create a new Azure AD application and credentials
    }
    "2" {
        # Ask for the specific tenant to run against
        Write-Host ""
        Display-ExistingTenants
        Write-Host ""
        $existingCredentials = @(Import-Csv -Path $csvPathCred)
        for ($i=0; $i -lt $existingCredentials.Count; $i++) {
            Write-Host "$($i+1): $($existingCredentials[$i].TenantName)"
        }
        Write-Host ""
        $tenantChoiceIndex = Read-Host "Enter the number of the tenant you want to run against"
        Write-Host ""
        # Check if the user's choice is a valid number
        if ($tenantChoiceIndex -notmatch '^\d+$' -or $tenantChoiceIndex -le 0 -or $tenantChoiceIndex -gt $existingCredentials.Count) {
            Write-Host "Invalid choice. Exiting script."
            exit
        }
        # Retrieve the selected tenant
        $selectedTenant = $existingCredentials[$tenantChoiceIndex - 1]
        if ($selectedTenant) {
            $currentTenant += $selectedTenant
            $certificateThumbprint = $selectedTenant.CertificateThumbprint # Retrieve the certificate thumbprint for the selected tenant
        } else {
            Write-Host "Tenant not found in the CSV file."
            exit
        }
    }
    "3" {
        # Run against all tenants
        Display-ExistingTenants
        Write-Host ""
        if (Test-Path $csvPathCred) {
            $existingCredentials = Import-Csv -Path $csvPathCred
            $currentTenant += $existingCredentials
        } else {
            Write-Host "CSV file not found."
            exit
        }
    }
    default {
        Write-Host "Invalid choice. Exiting script."
        exit
    }
}

# If the user chose to add a new tenant, the script will continue to the section where a new Azure AD application is created
# If the user chose an existing tenant or all tenants, the script will skip the creation and proceed with the next steps

if ($userChoice -eq "1") {
    # Sign in to Azure AD with modern authentication
    Connect-AzureAD

    # Retrieve the tenant details, tenant name, and fallback domain name
    $tenantDetails = Get-AzureADTenantDetail
    $tenantName = $tenantDetails.DisplayName
    $fallbackDomain = ($tenantDetails.VerifiedDomains | Where-Object { $_.Initial -eq $true }).Name

    # Check if the tenant has already been added
    $existingCredentials = @()
    if (Test-Path $csvPathCred) {
        $existingCredentials = @(Import-Csv -Path $csvPathCred)
        $tenantAlreadyAdded = $existingCredentials | Where-Object { $_.TenantID -eq $tenantDetails.ObjectId }
        if ($tenantAlreadyAdded) {
            Write-Host "This tenant has already been added."
            return
        }
    }

    # Create a new Azure AD application
    $appName = "Microsoft Intune PowerShell"
    $app = New-AzureADApplication -DisplayName $appName

    # Create a self-signed certificate
    $certificate = Create-SelfSignedCertificate -certificateName $appName -tenantName $tenantName

    # Upload the certificate to the Azure AD application
    $certValue = [System.Convert]::ToBase64String($certificate.GetRawCertData())
    New-AzureADApplicationKeyCredential -ObjectId $app.ObjectId -CustomKeyIdentifier "IntuneAppCert" -Type AsymmetricX509Cert -Usage Verify -Value $certValue

    # Store the TenantID, TenantName, Domain, ClientID, and CertificateThumbprint in the CSV file
    $newCredential = @{
        TenantID = $tenantDetails.ObjectId
        TenantName = $tenantName
        Domain = $fallbackDomain
        ClientID = $app.AppId
        CertificateThumbprint = $certificate.Thumbprint
    }
    $credentialObject = New-Object -TypeName PSObject -Property $newCredential

    # Append the new tenant information to the CSV file
    $existingCredentials += $credentialObject
    $existingCredentials | Export-Csv -Path $csvPathCred -NoTypeInformation -Force

    # Get the Service Principal for your Azure AD Application
    $servicePrincipal = Get-AzureADServicePrincipal -Filter "appId eq '$($app.AppId)'"
    if ($null -eq $servicePrincipal) {
        Write-Host "Service Principal for the app not found. Creating one..."
        $servicePrincipal = New-AzureADServicePrincipal -AppId $app.AppId
    }

    # Define required Microsoft Graph permissions
    $requiredPermissions = @(
        "DeviceManagementManagedDevices.PrivilegedOperations.All",
        "DeviceManagementManagedDevices.ReadWrite.All",
        "DeviceManagementRBAC.ReadWrite.All",
        "DeviceManagementApps.ReadWrite.All",
        "DeviceManagementConfiguration.ReadWrite.All",
        "DeviceManagementServiceConfig.ReadWrite.All",
        "Group.ReadWrite.All",
        "Directory.Read.All",
        "User.Read",
        "Group.Read.All"
    )

    # Get the Microsoft Graph service principal
    $graphServicePrincipal = Get-AzureADServicePrincipal -Filter "DisplayName eq 'Microsoft Graph'"
    if ($null -eq $graphServicePrincipal) {
        Write-Host "Microsoft Graph service principal could not be found."
        exit
    }

    # Add permissions to the service principal
    foreach ($permission in $requiredPermissions) {
        # Find the Microsoft Graph permission
        $graphPermission = $graphServicePrincipal.AppRoles | Where-Object { $_.Value -eq $permission -and $_.AllowedMemberTypes -contains "Application" }
        if ($null -ne $graphPermission) {
            # Check if the permission already exists
            $exists = $currentPermissions | Where-Object { $_.Id -eq $graphPermission.Id }
            if ($null -eq $exists) {
                # Add the permission to the service principal
                New-AzureADServiceAppRoleAssignment -ObjectId $servicePrincipal.ObjectId -PrincipalId $servicePrincipal.ObjectId -ResourceId $graphServicePrincipal.ObjectId -Id $graphPermission.Id
                Write-Host "Added permission: $permission"
            } else {
                Write-Host "Permission already assigned: $permission"
            }
        } else {
            Write-Host "Permission not found or not an application permission: $permission"
        }
    }

    # Correctly capture the application ID and tenant ID
    $clientId = $app.AppId
    $tenantId = $tenantDetails.ObjectId

    # Generate the Azure portal API permissions link with the correct application ID
    $azurePortalPermissionsLink = "https://portal.azure.com/#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/CallAnAPI/appId/$clientId"

    # Prompt the user to configure permissions in the Azure portal
    Write-Host ""
    Write-Host "Please go to the following URL in your browser and configure the required API permissions for the application:"
    Write-Host $azurePortalPermissionsLink
    Write-Host ""

    # Wait for the user to confirm that admin consent has been granted
    $userConsentGranted = $false
    do {
        $userConsentResponse = Read-Host "Have you granted admin consent in the browser? (yes/no)"
        if ($userConsentResponse -eq "yes") {
            $userConsentGranted = $true
            Write-Host "Tenant $($tenantName): SUCCESS - Tennant added."
            exit
        }
    } while (-not $userConsentGranted)
}

# Ask user for application choice
Write-Host "Please select an application to install:"
$applications = @(Import-Csv -Path $csvPathApps)
Write-Host "0: All Applications"
for ($i = 0; $i -lt $applications.Count; $i++) {
    Write-Host "$($i+1): $($applications[$i].DisplayName)"
}

$selectedAppIndex = Read-Host "Enter the number of the application you want to install (0 for all)"
$selectedAppIndex = [int]$selectedAppIndex

if ($selectedAppIndex -lt 0 -or $selectedAppIndex -gt $applications.Count) {
    Write-Host "Invalid choice. Exiting script."
    exit
}

$selectedApps = @()
if ($selectedAppIndex -eq 0) {
    $selectedApps += $applications
} else {
    $selectedApps += $applications[$selectedAppIndex - 1]
}

# Process selected applications
foreach ($env in $currentTenant) {
    foreach ($app in $selectedApps) {
        $results = Process-Application -Application $app -currentTenant $env -Win32AppsFolder $Win32AppsFolder
        # Check if results are returned and append them to $report
        if ($results) {
            $report += $results
        }
    }
}

# Final report
Write-Host ""
Write-Host "Final Report:"
foreach ($entry in $report) {
    Write-Host $entry
}