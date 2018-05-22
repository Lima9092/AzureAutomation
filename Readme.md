Automates the creation/deletion of the following Azure resources as defined in CSV files generated from a the 'Azure Lab.xlsx' spreadsheet
- Resource Groups
- Storage Accounts
- Virtual Networks
- Subnets
- Network Security Groups
- NSG Rules
- Virtual Machines

AzureBuilder.xlsx
--------------
Used to complete the virtual machine, storage and virtual network configuration details and export working CSV files.

Good lab candidates B series VM's pre-populated in drop down list and includes price estimates for lab.


InstallAzurePSH.ps1
----------------
Installs the modules required in Powershell to run the Azure Resource Manager Scripts


BuildAzure.ps1
-------------
Script written to be flexible and work with geo split labs where quotas limit CPU. Multiple 'Azure Lab.xlsx' files can be used and appended to one large multi location CSV files.

VM's built with Std HDD storage to reduce cost and remove costs occuring when VMs are off.

Network Security Groups not created per VM but per subnet.

RDP TCP port 3389 allowed through subnet NSGs for remote management.

WinRM HTTPS port 5986 allowed through subnet NSGs for remote Powershell.

Choice between pre-populated VM creds in script or being prompted (default prompt is commented out).

Custom Script Extension is used during build to run a powershell script from a hardcoded Storage Account Blob Container once the VM is
built to create a self-signed certificate and configure WinRM over HTTPS which prepares the VMs for remote Powershell and further automation within the environment such as 'ConfigAD.ps1'.

Local Dependancies:
- AzureStorage.csv
- AzureNetwork.csv
- AzureVMs.csv

Hosted Dependency: (Only required to configure WinRM HTTPS Remote Powershell)
- AzureWinRMHTTPS.ps1


AzureWinRMHTTPS.ps1
-------------------
Script is hardcoded to download the script from an Azure Storage Account. Can be configured to pull from another source such as a GitHub Repo.

Enables WinRM HTTPS port 5986 through Windows Firewall to enable Remote Powershell.

Creates a self-signed certicate and configures WinRM to listen on HTTPS default port using the self-signed certificate.

Dependencies:
- Confgiuration in CreateLab.ps1 for a location and authorisation to download the AzureWinRMHTTPS.ps1 script


ConfigureAD.ps1
------------
Installs and configures Active Directory Domain Controllers and Member Servers for the specified domain using Remote Powershell over SSL port 5896.

There is a lookup against 'Type' variable in 'AzureVMs.csv' to determin if the server is a 'Domain Controller', 'Member Server' or 'Stabndalone' and which Active Directory Domain is relevant for that Virtual Machine anc the script configures accordingly.

Dependencies:
AzureVMs.ps1


DeleteAzure.ps1
-------------
Deletes all 'Resource Groups' (including all resources) defined in AzureStorage.csv.

Dependencies:
- AzureStorage.csv

CSV Files (ensure no dirty entries such as rogue ,,,,)
---------
- AzureStorage.csv
- AzureNetwork.csv
- AzureVMs.csv
