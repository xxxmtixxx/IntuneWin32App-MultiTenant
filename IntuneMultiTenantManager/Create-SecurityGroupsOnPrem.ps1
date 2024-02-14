# Define the list of service groups with their descriptions
$serviceGroups = @{	"!!_7Zip" = "7-Zip";
	"!!_AdobeAcrobat" = "Adobe Acrobat";
	"!!_AutoCAD" = "AutoCAD";
	"!!_Bluebeam" = "Bluebeam";
	"!!_GoogleEarthPro" = "Google Earth Pro";
	"!!_Revit" = "Revit";
	"!!_RingCentral" = "RingCentral";
	"!!_SketchUp" = "SketchUp";
	"!!!_Microsoft_Teams_Phone_Standard" = "Microsoft Teams Phone Standard";
	"!!!_Visio_Plan_1" = "Visio Plan 1";
	"!!!_Microsoft_365_E3" = "Microsoft 365 E3";
	"!!!_M365_Business_Premium" = "M365 Business Premium";
	"!!!_Microsoft_365_E5" = "Microsoft 365 E5";
	"!!!_Office_365_E3" = "Office 365 E3";
	"!!!_Microsoft_365_Audio_Conferencing" = "Microsoft 365 Audio Conferencing";
	"!!!_Visio_Plan_2" = "Visio Plan 2";
	"!!!_Project_Plan_3" = "Project Plan 3";
	"!!!_Project_Plan_5" = "Project Plan 5";
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
        Write-Host "Group $GroupName already exists in AD."
    } else {
        try {
            # Create the new group in the specified OU
            New-ADGroup -Name $GroupName -GroupScope Global -Description $Description -Path $OUPath
            Write-Host "Group $GroupName created successfully in AD with description: '$Description'."
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
    $securityGroupsOU = "OU=Security Groups Sync,$($localDomain.DistinguishedName)"

    # Iterate over the service groups and create them with their descriptions in the Security Groups OU
    foreach ($group in $serviceGroups.Keys) {
        Create-ADServiceGroup -GroupName $group -Description $serviceGroups[$group] -OUPath $securityGroupsOU
    }

    Write-Host "All AD service groups have been processed. Starting Entra Connect Delta Sync."
    Start-ADSyncSyncCycle -PolicyType Delta | Out-Null
} catch {
    Write-Host "Error: Unable to find local domain. Please ensure you are connected to a domain and try again."
    exit
}
