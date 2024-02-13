# Define the list of service groups with their descriptions
$serviceGroups = @{	"!!_7Zip" = "7-Zip";
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
        [string]$Description,
        [string]$OUPath
    )

    # Check if the group already exists in the specified OU
    $groupExists = Get-ADGroup -Filter "Name -eq '$GroupName'" -SearchBase $OUPath -ErrorAction SilentlyContinue

    if ($groupExists) {
        Write-Host "Group $GroupName already exists in $OUPath."
    } else {
        try {
            # Create the new group in the specified OU
            New-ADGroup -Name $GroupName -GroupScope Global -Description $Description -Path $OUPath
            Write-Host "Group $GroupName created successfully with description: '$Description' in $OUPath."
        } catch {
            Write-Host "Error creating group ${GroupName}: $_"
        }
    }
}

# Get the local domain to ensure we are creating groups in the correct domain
try {
    $localDomain = Get-ADDomain
    Write-Host ""
    
    # Construct the distinguished name for the Security Groups OU
    $securityGroupsOU = "OU=Security Groups,$($localDomain.DistinguishedName)"

    # Iterate over the service groups and create them with their descriptions in the Security Groups OU
    foreach ($group in $serviceGroups.Keys) {
        Create-ADServiceGroup -GroupName $group -Description $serviceGroups[$group] -OUPath $securityGroupsOU
    }

    Write-Host "All service groups have been processed."
} catch {
    Write-Host "Error: Unable to find local domain. Please ensure you are connected to a domain and try again."
    exit
}
