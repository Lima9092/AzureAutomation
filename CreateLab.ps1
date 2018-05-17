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

# Configure Virtual Network and loop through Subnet and NSGs
  $csv = import-csv AzureNetwork.csv 
  $csv | foreach-object {
  $Location = $_.'Location'
  $ResourceGroup = $_.'ResourceGroup'
  $VirtualNetworkName = $_.'VirtualNetwork'
  $Address = $_.'Address'
  $SubnetName = $_.'Subnet'
  $SubnetAddress = $_.'Network'
  $nsgName = "$SubnetName-nsg"

  # Create Virtual Network Confgiurations Objects
    $frontendSubnet = New-AzureRmVirtualNetworkSubnetConfig `
      -Name $SubnetName `
      -AddressPrefix $SubnetAddress

    $virtualNetwork = New-AzureRmVirtualNetwork `
     -Name $VirtualNetworkName `
     -ResourceGroupName $ResourceGroup `
      -Location $Location `
      -AddressPrefix $vnetAddress `
      -Subnet $frontendSubnet `
      -Force

  # Create RDP Rule
    $rdpRule = New-AzureRmNetworkSecurityRuleConfig `
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

  # Create network security groups
    $networkSecurityGroup = New-AzureRmNetworkSecurityGroup `
     -ResourceGroupName $ResourceGroup `
     -Location $Location `
     -Name $nsgName `
     -SecurityRules $rdpRule

  # Assign NSGs to Subnets
    Set-AzureRmVirtualNetworkSubnetConfig `
    -Name $SubnetName `
    -VirtualNetwork $VirtualNetworkName `
    -AddressPrefix $SubnetAddress `
    -NetworkSecurityGroup $networkSecurityGroup

    $virtualNetwork | Set-AzureRmVirtualNetwork
  }

# Create virtual machines
  $csv = import-csv AzureVMS.csv 
  $csv | foreach-object {
  $Location = $_.'Location'
  $ResourceGroup = $_.'ResourceGroup' 
  $VMName = $_.'VMName'
  $VMSize = $_.'VMSize' 
  $VirtualNetwork = $_.'VirtualNetwork' 
  $Subnet = $_.'Subnet'
  $IPAddress = $_.'IPAddress'
  $PublisherName = $_.'PublisherName'
  $Offer = $_.'Offer'
  $Skus = $_.'Skus'
  $osDiskSAUri = $_.'osDiskSAUri'

  #Create Virtual Network Interface
  $nic = New-AzureRmNetworkInterface `
    -Name "$VMName-vnic" `
    -ResourceGroupName $ResourceGroup `
    -Location $Location `
    -Subnet $Subnet `
    -PrivateIpAddress $IPAddress `
    -PublicIpAddressId $pip.Id `

  # Prompt for credentials
  #$cred = Get-Credential -Message "Enter a username and password for the virtual machine."

  # Create username and password creds for the virtual machines
  $UserName='ttpadmin'
  $Password='Password@123'| ConvertTo-SecureString -Force -AsPlainText
  $Credential=New-Object PSCredential($UserName,$Password)

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

  $osDiskName = "$VMName-osd"
  $vhdDiskName = "$VMName.vhd"
  $osDiskUri = $osDiskSAUri+$vhdDiskName -f `
    $StorageAccount.PrimaryEndpoints.Blob.ToString(), `
    $vmName.ToLower(), `
    $osDiskName

  # Sets the operating system disk properties
  $VirtualMachine = Set-AzureRmVMOSDisk `
    -VM $VirtualMachine `
    -Name $osDiskName `
    -VhdUri $OsDiskUri `
    -CreateOption FromImage | `
    Add-AzureRmVMNetworkInterface -Id $nic.Id

  # Create the virtual machine
  New-AzureRmVM `
    -ResourceGroupName $ResourceGroup `
    -Location $Location `
    -VM $VirtualMachine
  }