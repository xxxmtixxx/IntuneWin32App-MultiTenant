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

# Function to create a new AD group with a description
function Create-ADServiceGroup {
    param(
        [string]$GroupName,
        [string]$Description
    )

    # Check if the group already exists
    $groupExists = Get-ADGroup -Filter "Name -eq '$GroupName'" -ErrorAction SilentlyContinue

    if ($groupExists) {
        Write-Host "**Group $GroupName already exists.**"
    } else {
        try {
            # Create the new group
            New-ADGroup -Name $GroupName -GroupScope Global -Description $Description -Path "CN=Users,$((Get-ADDomain).DistinguishedName)"
            Write-Host "**Group $GroupName created successfully with description: '$Description'.**"
        } catch {
            Write-Host "**Error creating group $GroupName: $_**"
        }
    }
}

# Get the local domain to ensure we are creating groups in the correct domain
try {
    $localDomain = Get-ADDomain
    Write-Host "**Local domain found: $($localDomain.Name)**"
} catch {
    Write-Host "**Error: Unable to find local domain. Please ensure you are connected to a domain and try again.**"
    exit
}

# Iterate over the service groups and create them with their descriptions
foreach ($group in $serviceGroups.Keys) {
    Create-ADServiceGroup -GroupName $group -Description $serviceGroups[$group]
}

Write-Host "**All service groups have been processed.**"