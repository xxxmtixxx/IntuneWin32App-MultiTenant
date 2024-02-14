# Define the path to the CSV file relative to the script's location
$csvPath = Join-Path -Path $PSScriptRoot -ChildPath "Requirements\applications.csv"

Write-Host ""

# Install the required module if not already installed
if (-not (Get-Module -ListAvailable -Name "MSOnline")) {
    Install-Module -Name MSOnline -Force -AllowClobber
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
        Write-Host "Group $GroupName already exists in Office 365."
    } else {
        # Create the new group
        New-MsolGroup -DisplayName $GroupName -Description $Description
        Write-Host "Group $GroupName created successfully in Office 365 with description: '$Description'."
    }
}

# Connect to MS Online Service
Connect-MsolService

# Check if the CSV file exists before attempting to import
if (Test-Path -Path $csvPath) {
    # Import the list of service groups from the CSV file
    $serviceGroups = Import-Csv -Path $csvPath

    # Create a unique list of groups from the CSV
    $uniqueServiceGroups = $serviceGroups | 
        Group-Object -Property securityGroupName | 
        ForEach-Object { $_.Group | Select-Object -First 1 }
} else {
    Write-Host "CSV file not found at path $csvPath"
    exit
}

# Define static groups and their descriptions with corrected property names
$staticGroups = @(
    @{securityGroupName="!!!_M365_Business_Premium"; securityGroupNameDescription="M365 Business Premium"},
    @{securityGroupName="!!!_Microsoft_365_E5"; securityGroupNameDescription="Microsoft 365 E5"},
    @{securityGroupName="!!!_Microsoft_365_E3"; securityGroupNameDescription="Microsoft 365 E3"},
    @{securityGroupName="!!!_Office_365_E3"; securityGroupNameDescription="Office 365 E3"},
    @{securityGroupName="!!!_Microsoft_365_Audio_Conferencing"; securityGroupNameDescription="Microsoft 365 Audio Conferencing"},
    @{securityGroupName="!!!_Microsoft_Teams_Phone_Standard"; securityGroupNameDescription="Microsoft Teams Phone Standard"},
    @{securityGroupName="!!!_Project_Plan_3"; securityGroupNameDescription="Project Plan 3"},
    @{securityGroupName="!!!_Project_Plan_5"; securityGroupNameDescription="Project Plan 5"},
    @{securityGroupName="!!!_Visio_Plan_1"; securityGroupNameDescription="Visio Plan 1"},
    @{securityGroupName="!!!_Visio_Plan_2"; securityGroupNameDescription="Visio Plan 2"}
)

# Convert static groups to objects with corrected property names
$staticGroupObjects = $staticGroups | ForEach-Object { 
    New-Object PSObject -Property @{
        securityGroupName = $_.securityGroupName
        securityGroupNameDescription = $_.securityGroupNameDescription
    }
}

# Combine static groups with the unique groups from the CSV
$allGroupsToProcess = $uniqueServiceGroups + $staticGroupObjects

# Iterate over the combined list of unique service groups and create them
foreach ($group in $allGroupsToProcess) {
    Create-O365Group -GroupName $group.securityGroupName -Description $group.securityGroupNameDescription | Out-Null
}

Write-Host "All Office 365 security groups have been processed."