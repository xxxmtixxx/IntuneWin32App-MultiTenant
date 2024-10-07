Function Remove-ExistingApplication {
    param (
        [string]$DisplayName
    )

    # Retrieve the application by display name
    $existingApp = Get-IntuneWin32App -DisplayName $DisplayName

    # If the application exists, remove it
    if ($existingApp) {
        Write-Host "Application $DisplayName exists. Proceeding with deletion..."
        Remove-IntuneWin32App -ID $existingApp.id
        Write-Host "Application $DisplayName has been removed from the tenant."
    } else {
        Write-Host "Application $DisplayName does not exist in the tenant."
    }
}