# Install Powershell Get
Install-Module PowerShellGet -Force

# Install the Azure Resource Manager modules from the PowerShell Gallery
Install-Module -Name AzureRM -AllowClobber

# Load the AzureRM module
Import-Module -Name AzureRM
