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

# Connect to MS Online Service
Connect-MsolService

# Define the path to the CSV file relative to the script's location
$csvPath = Join-Path -Path $PSScriptRoot -ChildPath "Requirements\applications.csv"

# Check if the CSV file exists before attempting to import
if (Test-Path -Path $csvPath) {
    # Import the list of service groups from the CSV file
    $serviceGroups = Import-Csv -Path $csvPath
} else {
    Write-Host "CSV file not found at path $csvPath"
    exit
}

# Iterate over the service groups and create them with their descriptions
foreach ($group in $serviceGroups) {
    Create-O365Group -GroupName $group.securityGroupName -Description $group.securityGroupNameDescription
}

Write-Host "**All Office 365 groups have been processed.**"