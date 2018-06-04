$CSEStorageAccountName = "Enter Storage Account Name for Custom Script Extension Here"
$CSEStorageAccountKey = "Enter Storage Account Key for Custom Script Extension Here"

# Set Local Admin Credentials
$UserName = Read-Host "Enter administrator username for Azure VMs: (Cannot be 'admin' or 'administrator' in Azure)"
do {
Write-Host "`nEnter administrator password for Azure VMs`n"
$PrePassword = Read-Host "Password" -AsSecureString
$Password = Read-Host "Confirm Password" -AsSecureString
$PrePassword_text = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($PrePassword))
$Password_text = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password))
}
while ($PrePassword_text -ne $Password_text)
Write-Host "`nPassword succesffuly set`n"

#Connect to Azure
Connect-AzureRmAccount

# Create Resource Groups and Storage Accounts
  $csv = import-csv AzureStorage.csv 
  $csv | foreach-object {
  $Location = $_.'Location'
  $ResourceGroup = $_.'ResourceGroup'
  $StorageAccountName = $_.'StorageAccount'
  $Redundancy = $_.'Redundancy'

  # Create a Resource Rroup
  New-AzureRmResourceGroup -Name $ResourceGroup `
    -Location $Location

  # Create a new storage account
  $StorageAccount = New-AzureRMStorageAccount `
    -Location $Location `
    -ResourceGroupName $ResourceGroup `
    -SkuName $Redundancy `
    -Name $StorageAccountName

  Set-AzureRmCurrentStorageAccount `
    -StorageAccountName $StorageAccountName `
    -ResourceGroupName $ResourceGroup `

  # Create a storage container to store the virtual machine image
  $containerName = 'osdisks'
  $container = New-AzureStorageContainer `
    -Name $containerName `
    -Permission Blob
  }

# Create Virtual Network
  $csv = import-csv AzureNetwork.csv
  $csv | foreach-object {
  $Location = $_.'Location'
  $ResourceGroup = $_.'ResourceGroup'
  $vnetAddress = $_.'Address'
  $VirtualNetworkName = $_.'VirtualNetwork'

  $virtualNetwork = New-AzureRmVirtualNetwork `
    -ResourceGroupName $ResourceGroup `
    -Location $Location `
    -Name $VirtualNetworkName `
    -AddressPrefix $vnetAddress `
    -Force
  }

  # Create RDP Rule
  $Rule1 = New-AzureRmNetworkSecurityRuleConfig `
    -Name RDP `
    -Description "Allow RDP" `
    -Access Allow `
    -Protocol Tcp `
    -Direction Inbound `
    -Priority 100 `
    -SourceAddressPrefix Internet `
    -SourcePortRange * `
    -DestinationAddressPrefix * `
    -DestinationPortRange 3389

  $Rule2 = New-AzureRmNetworkSecurityRuleConfig `
    -Name WinRM-HTTPS `
    -Description "Allow WinRM HTTPS" `
    -Access Allow `
    -Protocol Tcp `
    -Direction Inbound `
    -Priority 101 `
    -SourceAddressPrefix Internet `
    -SourcePortRange * `
    -DestinationAddressPrefix * `
    -DestinationPortRange 5986

  #Create subnets and NSGs
  $csv = import-csv AzureNetwork.csv
  $csv | foreach-object {
  $VirtualNetworkName = $_.'VirtualNetwork'
  $SubnetName = $_.'Subnet'
  $SubnetAddress = $_.'Network'

  $subnetConfig = Add-AzureRmVirtualNetworkSubnetConfig `
    -Name $SubnetName `
    -AddressPrefix $SubnetAddress `
    -VirtualNetwork $virtualNetwork

  # Create network security groups
  $nsgName = "$SubnetName-nsg"
  $networkSecurityGroup = New-AzureRmNetworkSecurityGroup `
   -ResourceGroupName $ResourceGroup `
   -Location $Location `
   -Name $nsgName `
   -SecurityRules $Rule1, $Rule2

  # Assign NSGs to Subnets
    Set-AzureRmVirtualNetworkSubnetConfig `
      -Name $SubnetName `
      -VirtualNetwork $virtualNetwork `
      -AddressPrefix $SubnetAddress `
      -NetworkSecurityGroup $networkSecurityGroup
  }

  $virtualNetwork | Set-AzureRmVirtualNetwork

# Create virtual machines  
  $csv = import-csv AzureVMS.csv 
  $csv | foreach-object {
  $Location = $_.'Location'
  $ResourceGroup = $_.'ResourceGroup' 
  $VMName = $_.'VMName'
  $VMSize = $_.'VMSize' 
  $VirtualNetworkName = $_.'VirtualNetwork' 
  $Subnet = $_.'Subnet'
  $IPAddress = $_.'IPAddress'
  $PublisherName = $_.'PublisherName'
  $Offer = $_.'Offer'
  $Skus = $_.'Skus'
  $osDiskSAUri = $_.'osDiskSAUri'

  # Create credential object for the virtual machines
  $Credential = New-Object PSCredential($UserName,$Password)

  #Create Virtual Network Interface
  $SubnetID = Get-AzureRmVirtualNetwork `
    -Name $VirtualNetworkName `
    -ResourceGroupName $ResourceGroup | `
    Get-AzureRmVirtualNetworkSubnetConfig `
    -Name $Subnet | `
    Select -ExpandProperty Id

  # Create a public IP address and specify a DNS name
  $pip = New-AzureRmPublicIpAddress `
    -ResourceGroupName $ResourceGroup `
    -Location $Location `
    -AllocationMethod Dynamic `
    -IdleTimeoutInMinutes 4 `
    -DomainNameLabel "$VMName-$ResourceGroup" `
    -Name "$VMName-pip"
  
  # Create a virtual network card and associate it with public IP address
  $nic = New-AzureRmNetworkInterface `
    -Name "$VMName-vnic" `
    -ResourceGroupName $ResourceGroup `
    -Location $Location `
    -SubnetID $SubnetID `
    -PrivateIpAddress $IPAddress `
    -PublicIpAddressId $pip.Id `

  # Create the virtual machine configuration object
  $VirtualMachine = New-AzureRmVMConfig `
    -VMName $VMName `
    -VMSize $VMSize

  $VirtualMachine = Set-AzureRmVMOperatingSystem `
    -VM $VirtualMachine `
    -Windows `
    -ComputerName $VMName `
    -Credential $Credential

  $VirtualMachine = Set-AzureRmVMSourceImage `
    -VM $VirtualMachine `
    -PublisherName $PublisherName `
    -Offer $Offer `
    -Skus $Skus `
    -Version "latest"

  # Sets the operating system disk properties
  $VirtualMachine = Set-AzureRmVMOSDisk `
    -VM $VirtualMachine `
    -Name $VMName-osd `
    -VhdUri $osDiskSAUri `
    -CreateOption FromImage | `
    Add-AzureRmVMNetworkInterface -Id $nic.Id

  # Disables creating boot diagnostics drive
  $VirtualMachine = Set-AzureRmVMBootDiagnostics `
    -VM $VirtualMachine -Disable

  # Create the virtual machine
  New-AzureRmVM `
    -ResourceGroupName $ResourceGroup `
    -Location $Location `
    -VM $VirtualMachine
  }

# Run custom script extension to create self-signed cert and enable WinRM
  $csv = import-csv AzureVMS.csv 
  $csv | foreach-object {
  $Location = $_.'Location'
  $ResourceGroup = $_.'ResourceGroup' 
  $VMName = $_.'VMName'
  Set-AzureRmVMCustomScriptExtension `
    -ResourceGroupName $ResourceGroup `
    -Location $Location `
    -VMName $VMName `
    -Name "WinRM" `
    -TypeHandlerVersion "1.1" `
    -StorageAccountName $CSEStorageAccountName `
    -StorageAccountKey $CSEStorageAccountKey `
    -FileName "AzureWinRMHTTPS.ps1" `
    -ContainerName "scripts"
  }
