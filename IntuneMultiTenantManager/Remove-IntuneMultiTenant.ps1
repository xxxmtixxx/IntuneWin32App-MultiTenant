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

# Now, ask the user for their choice of application
Write-Host "Please select an application to remove:"
$applications = @(Import-Csv -Path $csvPathApps)

for ($i = 0; $i -lt $applications.Count; $i++) {
    $app = $applications[$i]
    Write-Host "$($i+1): $($app.DisplayName)"
}

Write-Host ""
$selectedAppIndex = Read-Host "Enter the number of the application you want to remove"
$selectedAppIndex = [int]$selectedAppIndex  # Cast to an integer

if ($selectedAppIndex -le 0 -or $selectedAppIndex -gt $applications.Count) {
    Write-Host "Invalid choice. Exiting script."
    exit
}

# Retrieve the selected application details
$selectedApp = $applications[$selectedAppIndex - 1]
if ($selectedApp) {
    $DisplayName = $selectedApp.DisplayName
    $Description = $selectedApp.Description
    $Publisher = $selectedApp.Publisher
    $InstallExperience = $selectedApp.InstallExperience
    $SetupFile = $selectedApp.SetupFile
    $UninstallCommandLine = $selectedApp.UninstallCommandLine
    $securityGroupName = $selectedApp.securityGroupName
} else {
    Write-Host "Application not found in the CSV file."
    exit
}

# Assuming $currentTenant is populated with the correct credential sets from previous selections
$intuneEnvironments = $currentTenant

foreach ($env in $intuneEnvironments) {
    # Retrieve the certificate from the certificate store
    $certificate = Get-Item -Path Cert:\CurrentUser\My\$($env.CertificateThumbprint) -ErrorAction SilentlyContinue

    # Check if the certificate was retrieved successfully
    if ($null -eq $certificate) {
        Write-Host "Certificate with thumbprint $($env.CertificateThumbprint) not found."
        continue
    }

    # Sign in to Azure AD and Intune with modern authentication using the certificate
    try {
        Connect-MgGraph -TenantId $env.TenantId -ApplicationId $env.ClientId -CertificateThumbprint $certificate.Thumbprint
        $authHeader = Connect-MSIntuneGraph -TenantID $env.TenantId -ClientID $env.ClientId -ClientCert $certificate
    } catch {
        Write-Host "Failed to connect to Azure AD for Tenant ID: $($env.TenantId) with error: $_"
        continue
    }

    # Retrieve the application by display name
    $existingApp = Get-IntuneWin32App -DisplayName $DisplayName

    # If the application exists, remove it
    if ($existingApp) {
        Write-Host "Application $DisplayName exists. Proceeding with deletion..."
        Remove-IntuneWin32App -ID $existingApp.id
        Write-Host "Application $DisplayName has been successfully removed from the tenant: $($env.TenantName)."
        $report += "Application $DisplayName has been successfully removed from the tenant: $($env.TenantName)."
    } else {
        Write-Host "Application $DisplayName was not found in the tenant: $($env.TenantName)."
        $report += "Application $DisplayName was not found in the tenant: $($env.TenantName)."
    }
}

Write-Host ""
Write-Host "Final Report:"
foreach ($entry in $report) {
    Write-Host $entry
}