### `Disclaimer: Work in Progress`

Please note that this script and the associated PowerShell module, `IntuneWin32App-MultiTenant`, are currently a **Work in Progress (WIP)**. Users should exercise caution and use this script at their own risk. Key points to consider:

- **Unsecured Passwords:** The current version of the script and module handles certain sensitive information, such as CertificateThumbprints, in a manner that may not be fully secure. Users are advised to be mindful of where and how sensitive data is stored and managed when using these scripts.

- **Security Roadmap:** Enhancing the security features of this script, including the secure handling of passwords and sensitive data, is a priority on our development roadmap. Future updates aim to integrate more secure methods, such as leveraging the Windows Credential Manager, to store and retrieve sensitive information securely.

- **User Responsibility:** While we strive to improve the security and functionality of our scripts, it is the responsibility of the user to ensure that they are used in a secure and controlled environment. Users should review the script's operations and handle any sensitive data with care.

- **Feedback and Contributions:** As this is a work in progress, feedback and contributions from the community are welcome to enhance the script's security and overall functionality.

---

## Manual API Download/Install

 The module can be installed by unzipping the master zip into one of your powershell modules folder, or by running the following one-liner:

```powershell
$documentsPath=[Environment]::GetFolderPath('MyDocuments');$url='https://github.com/xxxmtixxx/IntuneWin32App-MultiTenant/archive/refs/heads/main.zip';$moduleName='IntuneWin32App-MultiTenant';$modulePath=Join-Path $documentsPath 'WindowsPowerShell\Modules';$tempPath=Join-Path $env:TEMP ($moduleName+'.zip');Invoke-WebRequest -Uri $url -OutFile $tempPath;$tempDir='.'+$moduleName+'_temp';$extractPath=Join-Path $HOME $tempDir;Expand-Archive -Path $tempPath -DestinationPath $extractPath -Force;$sourceFolder=Join-Path $extractPath 'IntuneWin32App-MultiTenant-main';$destinationFolder=Join-Path $modulePath $moduleName;$managerFolder=Join-Path $extractPath ('IntuneWin32App-MultiTenant-main\IntuneMultiTenantManager');$targetManagerFolder='C:\IntuneMultiTenantManager';if (!(Test-Path $destinationFolder)) {New-Item -Path $destinationFolder -ItemType Directory | Out-Null};Copy-Item -Path "$sourceFolder\*" -Destination $destinationFolder -Recurse -Force;if (!(Test-Path $targetManagerFolder)) {New-Item -Path $targetManagerFolder -ItemType Directory | Out-Null};Copy-Item -Path "$managerFolder\*" -Destination $targetManagerFolder -Recurse -Force
```

---

### `Add-IntuneMultiTenant.ps1`

**Description:**
This PowerShell script, `Add-IntuneMultiTenant.ps1`, is designed to streamline the management of Win32 applications in Microsoft Endpoint Manager (Intune) across multiple Azure AD tenants. The script offers functionalities such as adding new tenants, running processes against existing tenants, and handling Win32 app installations. Key features include:

- **Tenant Management:** Allows the addition of new tenants to the system, including creating a new Azure AD application and generating self-signed certificates.
- **Existing Tenant Processing:** Can run processes against a specified existing tenant, including Win32 app installations.
- **Bulk Tenant Operations:** Provides the ability to perform operations across all registered tenants.
- **Interactive User Interface:** Users are prompted to make selections and input information through a guided command-line interface.

**CSV Requirements:**
- `credentials.csv`: This file should contain tenant credentials and details, including TenantID, TenantName, Domain, ClientID, and CertificateThumbprint.
- `applications.csv`: This file needs to list the Win32 applications to be managed, including details like DisplayName, Description, Publisher, InstallExperience, SetupFile, and other relevant application attributes.

---

### `Remove-IntuneMultiTenant.ps1`

**Description:**
The `Remove-IntuneMultiTenant.ps1` script is designed for efficiently managing the removal of Win32 applications in a multi-tenant Microsoft Endpoint Manager (Intune) environment. It facilitates the deletion of applications across different Azure AD tenants. Its capabilities include:

- **Selective Application Removal:** Users can select a specific application to remove from the tenant’s Intune environment.
- **Bulk Operation Across Tenants:** Provides functionality to remove an application across all registered tenants.
- **Interactive Selection Process:** The script prompts the user to choose the application to be removed, enhancing user control and preventing accidental deletions.

**CSV Requirements:**
- `credentials.csv`: As with the add script, this CSV should include tenant credentials such as TenantID, TenantName, Domain, ClientID, and CertificateThumbprint.
- `applications.csv`: This should list the Win32 applications subject to potential removal, with necessary details like DisplayName, Description, Publisher, and other relevant fields.

---

**Note:** Both scripts require the `credentials.csv` and `applications.csv` files for their operations, as they rely on this data to manage applications across multiple tenants. Ensure these CSV files are up-to-date and located in the specified paths (`Requirements\credentials.csv` and `Requirements\applications.csv`) relative to the script's root directory. Additionally, the scripts are part of a larger PowerShell module, `IntuneWin32App-MultiTenant`, which contains various functions that these scripts utilize for managing Intune applications across multiple tenants.