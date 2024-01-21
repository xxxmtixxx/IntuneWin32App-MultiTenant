# Install the required module if not already installed
if (-not (Get-Module -ListAvailable -Name "MSOnline")) {
    Install-Module -Name MSOnline
}

# Import the MSOnline module
Import-Module MSOnline

# Function to create a new Office 365 group
function Create-O365Group {
    param(
        [string]$GroupName,
        [string]$Description
    )

    # Check if the group already exists
    $groupExists = Get-MsolGroup | Where-Object { $_.DisplayName -eq $GroupName }

    if ($groupExists) {
        Write-Host "**Group $GroupName already exists in Office 365.**"
    } else {
        # Create the new group
        New-MsolGroup -DisplayName $GroupName -Description $Description
        Write-Host "**Group $GroupName created successfully in Office 365 with description: '$Description'.**"
    }
}

# Prompt for Office 365 credentials with modern authentication
$credential = Get-Credential

# Connect to MS Online Service with the provided credentials
Connect-MsolService -Credential $credential

# Define the list of service groups with their descriptions
$serviceGroups = @{
    "!!_7Zip" = "7-Zip";
    "!!_AdobeAcrobat" = "Adobe Acrobat";
    "!!_AutoCAD" = "AutoCAD";
    "!!_Bluebeam" = "Bluebeam";
    "!!_GoogleEarthPro" = "Google Earth Pro";
    "!!_Revit" = "Revit";
    "!!_RingCentral" = "RingCentral";
    "!!_SketchUp" = "SketchUp";
}

# Iterate over the service groups and create them with their descriptions
foreach ($group in $serviceGroups.Keys) {
    Create-O365Group -GroupName $group -Description $serviceGroups[$group]
}

Write-Host "**All Office 365 groups have been processed.**"
