Introduction
------------

A set of scripts and a build tool in the form of an Excel Spreadsheet to provision a complete Azure Wintel Environment. There is a range of flexability within the spreadhseet and scripts. That said there are sections hardcoded based on cost effective decisions, such as unmanaged HDD storage over costlier managed SSDs. Currently the tools are ideal for dev/test labs or small environments.

An Azure subscription and accopanying authorisation is required. 

To perform further automation within the environment/s an Azure Storage Account with a Blob named 'scripts' and Storage Account Key is a pre-requisate. This allows a Custom Script Extension to be used to download a further script to configure the guest virtual machines for HTTPS Remote Powershell capability.

Is it advisable to manually create virtual machines in Azure Resource Manager prior to using this toolset to understand the underlying terms, technologies and specifics of Azure infrastructure. 


Overview
--------

Automates the creation/deletion of the following Azure resources as defined in CSV files generated from a the 'AzureBuilder.xlsx' spreadsheet
- Resource Groups
- Storage Accounts
- Virtual Networks
- Subnets
- Network Security Groups
- NSG Rules
- Virtual Machines


AzureBuilder.xlsx
-----------------
Used to complete the virtual machine, storage and virtual network configuration details and export working CSV files.

Good lab candidates B series VM's pre-populated in drop down list and includes price estimates for lab.


InstallAzurePSH.ps1
----------------
Installs the modules required in Powershell to run the Azure Resource Manager Scripts


BuildAzure.ps1
-------------
Script written to be flexible and work with geo split labs where quotas limit CPU. Multiple 'AzureBuilder.xlsx' files can be used and appended to a single set of CSV files.

VM's are hardcoded to use Std HDD storage to reduce cost and remove costs occuring when VMs are off. Redundancy levels can be altered.
SDD's require customization to the script.

Network Security Groups are not created per VM but per subnet.

RDP TCP port 3389 allowed through subnet NSGs for remote management.

WinRM HTTPS port 5986 allowed through subnet NSGs for remote Powershell.

Script prompts for all required credentials and variables at the beginning of the script.

Custom Script Extension is used during build to run a powershell script from a Storage Account Blob Container once the VM is
built to create a self-signed certificate and configure WinRM over HTTPS which prepares the VMs for remote Powershell and further automation within the environment such as 'ConfigureAD.ps1'.

Note. If used for a production environment PKI certificates should be used!

Local Dependancies:
- AzureStorage.csv
- AzureNetwork.csv
- AzureVMs.csv

Hosted Dependency: (Only required to configure WinRM HTTPS Remote Powershell)
- AzureWinRMHTTPS.ps1


AzureWinRMHTTPS.ps1
-------------------
BuildAzure.ps1 is coded to download AzureWinRMHTTPS.ps1 from an Azure Storage Account. Can be configured to pull from another source such as a GitHub Repo.

Enables WinRM HTTPS port 5986 through Windows Firewall to enable Remote Powershell.

Creates a self-signed certicate and configures WinRM to listen on HTTPS default port using the self-signed certificate.

Note. If used for a production environment PKI certificates should be used!

Dependencies:
- Prompted in AzureBuilder.ps1 for a Storage Account and corresponding Storage Access Key for the 'scripts' blob that contains AzureWinRMHTTPS.ps1 script.


ConfigureAD.ps1
------------
Installs and configures Active Directory Domain Controllers and Member Servers for the specified domains using Remote Powershell over SSL port 5896.

There is a lookup against 'Type' variable in 'AzureVMs.csv' to determine if the server is a 'Domain Controller', 'Member Server' or 'Stabndalone' server and which Active Directory Domain is relevant for that Virtual Machine. The script then promotes a DC or joins member serervs to their domain as per the configruation from 'AzureBuilder.xlsx' and subsequently 'AzureVMs.csv'.

Dependencies:
AzureVMs.csv


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
