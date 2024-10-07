### Modify these Variables ###
### URL to EXE, MSI, MSIX, or ZIP ###
$urlPath = "" # Ex: "SharePoint Link"
#### If ZIP, Must Specify Name of Sub-Folder\File After Extraction (Primary folder not required) ###
$nestedInstallerFolderAndFile = "" # Ex: "Setup.exe" or "subfolder\Setup.exe"
#### Specify Arguments ###
$arguments = "" # Ex: "--silent"
#### Specify Server File Path ###
$fileSharePath = "" # Ex: "\\FP\IT\Software\AutoDesk"

### Static Variables ###
if ($urlPath -match "sharepoint") { # Check if URL contains "sharepoint" and append "download=1" if true
    $urlPath = "$urlPath&download=1"
}
$head = Invoke-WebRequest -UseBasicParsing -Method Head $urlPath # Gets URL Header Info
$downloadFileName = $head.BaseResponse.ResponseUri.Segments[-1] # Extracts File Name from Header
$fileSharePathDownload = "$fileSharePath\$downloadFileName" # Server File Name
$downloadPath = "C:\Temp" # Local Temp Folder
$installer = "$downloadPath\$downloadFileName" # Local Installer Path
$extension = [IO.Path]::GetExtension($downloadFileName) # Get File Extension
$fileNamePrefix = [IO.Path]::GetFileNameWithoutExtension($downloadFileName) # Get File Name without Extension
$extractedPath = "$downloadPath\$fileNamePrefix" # Extracted ZIP Path
$nestedExtension = [IO.Path]::GetExtension($nestedInstallerFolderAndFile) # Get Nested File Extension
$nestedInstaller = "$extractedPath\$nestedInstallerFolderAndFile" # Get Nested File Name without Extension
$UAC = (Get-ItemProperty -path 'REGISTRY::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Policies\System').ConsentPromptBehaviorAdmin # Store Current UAC

### Disable UAC ###
Set-ItemProperty -Path REGISTRY::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Policies\System -Name ConsentPromptBehaviorAdmin -Value 0

### Create Local Temp Folder ###
if (!(Test-Path $downloadPath)) { # Check for Temp Folder
[void](New-Item -ItemType Directory -Force -Path $downloadPath) # Create Temp Folder
}

### Download from either S-FP or Web ###
if (Test-Path $fileSharePathDownload) { # Check for File on Server
Copy-Item -Path $fileSharePathDownload -Destination $installer # Copy File from Server
} else {
$ProgressPreference = 'SilentlyContinue' # Disable Download Status Bar
Invoke-WebRequest -Uri $urlPath -OutFile $installer # Download File from Web
}

### Install Application ###
if ($extension -eq ".exe") { # Check if EXE
Start-Process -FilePath $installer -ArgumentList $arguments -Verb RunAs -Wait # Install EXE
} elseif ($extension -eq ".msi") { # Check if MSI
Start-Process msiexec.exe -ArgumentList "/I ""$installer"" $arguments" -Verb RunAs -Wait # Install MSI
} elseif ($extension -eq ".msix") { # Check if MSIX
Add-AppPackage -Path $installer # Install MSIX
} elseif ($extension -eq ".zip") { # Check if ZIP
Expand-Archive -LiteralPath $installer -DestinationPath $extractedPath -Force # Extract ZIP
    if (Test-Path $extractedPath) { # Check for Extracted Folder
        if ($nestedExtension -eq ".exe") { # Check if EXE
        Start-Process -FilePath $nestedInstaller -ArgumentList $arguments -Verb RunAs -Wait # Install EXE
        } elseif ($nestedExtension -eq ".msi") { # Check if MSI
        Start-Process msiexec.exe -ArgumentList "/I ""$nestedInstaller"" $arguments" -Verb RunAs -Wait # Install MSI
        } elseif ($nestedExtension -eq ".msix") { # Check if MSIX
        Add-AppPackage -Path $nestedInstaller # Install MSIX
        }
    }
} else {
}

### Cleanup ###
Start-Sleep -Seconds 5 # Give Time for Installer to Close
Remove-Item -Path $installer -Force # Delete Installer
if (Test-Path $extractedPath) { # Check for Extracted Folder
Remove-Item -Path $extractedPath -Recurse -Force # Delete Extracted Folder
} else {
}

### Set UAC Back ###
Set-ItemProperty -Path REGISTRY::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Policies\System -Name ConsentPromptBehaviorAdmin -Value $UAC