# Function to check for Security Group
function Check-SecurityGroupExists {
    param (
        [string]$GroupName
    )
    $group = Get-MgGroup -Filter "displayName eq '$GroupName'"
    return $group
}