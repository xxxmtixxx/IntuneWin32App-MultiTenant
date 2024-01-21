Function Process-Application {
    param (
        [Parameter(Mandatory = $true)]
        $Application,
        $currentTenant,
        $Win32AppsFolder
    )

    $DisplayName = $Application.DisplayName
    $Description = $Application.Description
    $Publisher = $Application.Publisher
    $InstallExperience = $Application.InstallExperience
    $SetupFile = $Application.SetupFile
    $UninstallCommandLine = $Application.UninstallCommandLine
    $securityGroupName = $Application.securityGroupName

    # Initialize an array to hold report strings for each tenant
    $reportStrings = @()

    foreach ($env in $currentTenant) {
        # Retrieve the certificate from the certificate store
        $certificate = Get-Item -Path Cert:\CurrentUser\My\$($env.CertificateThumbprint) -ErrorAction SilentlyContinue

        if ($null -eq $certificate) {
            Write-Host "Certificate with thumbprint $($env.CertificateThumbprint) not found."
            continue
        }

        try {
            Connect-MgGraph -NoWelcome -TenantId $env.TenantId -ApplicationId $env.ClientId -CertificateThumbprint $certificate.Thumbprint
            $authHeader = Connect-MSIntuneGraph -TenantID $env.TenantId -ClientID $env.ClientId -ClientCert $certificate
        } catch {
            Write-Host "Failed to connect to Azure AD for Tenant ID: $($env.TenantId) with error: $_"
            continue
        }

        # Check for the existence of the security group
        $groupExists = Check-SecurityGroupExists -GroupName $securityGroupName

        if ($null -eq $groupExists) {
            Write-Host "Tenant $($env.TenantName): ERROR - Security group '$securityGroupName' does not exist."
            $reportStrings += "Tenant $($env.TenantName): ERROR - Security group '$securityGroupName' does not exist."
            continue
        }

        if ($null -ne $authHeader) {
        # Authentication successful, proceed with further actions
        # Check if the application already exists
        $existingApp = Get-IntuneWin32App -DisplayName $DisplayName

        if ($existingApp) {
            Write-Host "Tenant $($env.TenantName): INFO - $DisplayName already exists. Skipping..."
            #$report += "Tenant $($env.TenantName): INFO - $DisplayName already exists. Skipping..."
            $reportStrings += "Tenant $($env.TenantName): INFO - $DisplayName already exists. Skipping..."
            # Logic to update or skip the existing application
        } else {
            Write-Host "Tenant $($env.TenantName): INFO - $DisplayName does not exist. Proceeding with addition..."
            #$report += "Tenant $($env.TenantName): INFO - $DisplayName does not exist. Proceeding with addition..."
            $reportStrings += "Tenant $($env.TenantName): INFO - $DisplayName does not exist. Proceeding with addition..."
            # Package MSI as .intunewin file
            $SourceFolder = $Win32AppsFolder + "\" + $DisplayName + "\Source"
            $OutputFolder = $Win32AppsFolder + "\" + $DisplayName + "\Output"
            $ApplicationDetectionFolder = $Win32AppsFolder + "\" + $DisplayName + "\APPLICATIONDETECTION"
            $Win32AppPackage = New-IntuneWin32AppPackage -SourceFolder $SourceFolder -SetupFile $SetupFile -OutputFolder $OutputFolder -Verbose -Force

            # Get MSI meta data from .intunewin file
            $IntuneWinFile = $Win32AppPackage.Path
            $IntuneWinMetaData = Get-IntuneWin32AppMetaData -FilePath $IntuneWinFile

            # Create requirement rule for all platforms and Windows 10 20H2
            $RequirementRule = New-IntuneWin32AppRequirementRule -Architecture "All" -MinimumSupportedWindowsRelease "W10_20H2"  

            # Create PowerShell script detection rule
            $DetectionScriptFile = $ApplicationDetectionFolder + "\ApplicationDetection.ps1"
            $DetectionRule = New-IntuneWin32AppDetectionRuleScript -ScriptFile $DetectionScriptFile -EnforceSignatureCheck $false -RunAs32Bit $false

            # Create custom return code
            $ReturnCode = New-IntuneWin32AppReturnCode -ReturnCode 1337 -Type "retry"

            # Convert image file to icon
            $ImageFile = $Win32AppsFolder + "\" + $DisplayName + "\LOGO\logo.png"
            $Icon = New-IntuneWin32AppIcon -FilePath $ImageFile
            
            # Add new MSI Win32 app
            $InstallCommandLine = "powershell.exe -ExecutionPolicy Bypass -File .\" + $SetupFile
            # Add the Win32 app with or without AllowAvailableUninstall based on the CSV value
            if ($UninstallCommandLine -ne "N/A") {
                $Win32App = Add-IntuneWin32App -FilePath $IntuneWinFile -DisplayName $DisplayName -Description $Description -Publisher $Publisher -InstallExperience $InstallExperience -RestartBehavior "suppress" -DetectionRule $DetectionRule -RequirementRule $RequirementRule -ReturnCode $ReturnCode -Icon $Icon -InstallCommandLine $InstallCommandLine -UninstallCommandLine $UninstallCommandLine -AllowAvailableUninstall -Verbose
            } else {
                $Win32App = Add-IntuneWin32App -FilePath $IntuneWinFile -DisplayName $DisplayName -Description $Description -Publisher $Publisher -InstallExperience $InstallExperience -RestartBehavior "suppress" -DetectionRule $DetectionRule -RequirementRule $RequirementRule -ReturnCode $ReturnCode -Icon $Icon -InstallCommandLine $InstallCommandLine -UninstallCommandLine $UninstallCommandLine -Verbose
            }

            # Retrieve the group object by display name
            $group = Get-MgGroup -Filter "displayName eq '$securityGroupName'"

            # Extract the GUID (ObjectId) from the group object
            $GroupID = $group.Id

            try {
                    # Add group assignment
                    $result = Add-IntuneWin32AppAssignmentGroup -Include -ID $Win32App.id -GroupID $GroupID -Intent "available" -Notification "showAll" -Verbose
                    $resultString = "Tenant $($env.TenantName): SUCCESS - $DisplayName installed successfully."
                    $reportStrings += $resultString
                } catch {
                    Write-Host "Failed to add group assignment for $DisplayName. Error: $_"
                    try {
                        Remove-ExistingApplication -DisplayName $DisplayName
                        $reportStrings += "Tenant $($env.TenantName): ERROR - Failed to install $DisplayName and the application has been removed."
                    } catch {
                        $reportStrings += "Tenant $($env.TenantName): ERROR - Failed to remove $DisplayName after unsuccessful installation. Error: $_"
                    }
                }
                Start-Sleep -Seconds 5 
            }
        }
        else {
            Write-Warning "Failed to authenticate with Tenant ID: $($env.TenantId)"
            $report += "Tenant $($env.TenantName): FAILED - Cannot authenticate with tenant."
        }
    }
    # Return this string
    return ,$reportStrings
}