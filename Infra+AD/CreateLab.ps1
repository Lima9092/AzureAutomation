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

  # Create network Peering to Management VNet
  $ManagementVnet = 'Management-vnet' 
    Add-AzureRmVirtualNetworkPeering `
    -Name "Mgtvnet-$VirtualNetworkName" `
    -VirtualNetwork $ManagementVnet`
    -RemoteVirtualNetworkId $VirtualNetworkName.Id

      Add-AzureRmVirtualNetworkPeering `
    -Name "$VirtualNetworkName-Mgtvnet" `
    -VirtualNetwork $VirtualNetworkName `
    -RemoteVirtualNetworkId $ManagementVnet.Id
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
    -Priority 100 `
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
   -SecurityRules $Rule1, Rule2

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

  # Prompt for credentials
  # $cred = Get-Credential -Message "Enter a username and password for the virtual machine."

  # Create username and password creds for the virtual machines
  $UserName='ttpadmin'
  $Password='Password@123'| ConvertTo-SecureString -Force -AsPlainText
  $Credential=New-Object PSCredential($UserName,$Password)

  #Create Virtual Network Interface
  $SubnetID = Get-AzureRmVirtualNetwork `
    -Name $VirtualNetworkName `
    -ResourceGroupName $ResourceGroup | `
    Get-AzureRmVirtualNetworkSubnetConfig `
    -Name $Subnet | `
    Select -ExpandProperty Id
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

  # Run custom script extension to create self-signed cert and enable WinRM
    $VirtualMachine = Set-AzureRmVMCustomScriptExtension `
      -ResourceGroupName $ResourceGroup `
        -VMName $VMName `
        -Location $Location `
        -FileUri https://github.com/leejolley/AzureAutomation/tree/master/CustomScriptExtension `
        -Run 'AzureWinRMHTTPS.ps1' `
        -Name ConfigreWinRMHTTPS

  # Create the virtual machine
  New-AzureRmVM `
    -ResourceGroupName $ResourceGroup `
    -Location $Location `
    -VM $VirtualMachine

    }    
  
# Configure AD Domains
  $csv = import-csv AzureVMs.csv 
  $csv | foreach-object {
  $IPAddress = $_.'IPAddress'
  $Type = $_.'Type'
  $DomainName = $_.'DomainName'

  if ($Type -eq "Domain Controller") {

  # Set Credentials
  $UserName="ttpadmin"
  $Password="Password@123"| ConvertTo-SecureString -Force -AsPlainText
  $Credential=New-Object PSCredential($UserName,$Password)

  # Establish Remote PS Session   
  Enter-PSSession -ComputerName $IPAddress -Credential $Credential

  # Install ADDS and Promote Domain Controller
  Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
  Install-ADDSForest -DomainName $DomainName -InstallDns

  # Create OUs
  Import-Module -Name 'ActiveDirectory' -Force -NoClobber -ErrorAction Stop 

  New-ADOrganizationalUnit -Name $DomainName
  New-ADOrganizationalUnit -Name "Servers" - "OU=$DomainName,DC=$DC1,$DC2"
  New-ADOrganizationalUnit -Name "Users" - "OU=$DomainName,DC=$DC1,$DC2"
  New-ADOrganizationalUnit -Name "Groups" - "OU=$DomainName,DC=$DC1,$DC2"
  New-ADOrganizationalUnit -Name "Computers" - "OU=$DomainName,DC=$DC1,$DC2"
  }

  if ($Type -eq "Member Server") {

  # Set Credentials
  $UserName="$DomainName\ttpadmin"
  $Password="Password@123"| ConvertTo-SecureString -Force -AsPlainText
  $Credential=New-Object PSCredential($UserName,$Password)

  # Establish Remote PS Session   
  Enter-PSSession -ComputerName $IPAddress -Credential $Credential

  # Add server to domain and restart
  Add-Computer –DomainName $DomainName -Credential $Credential -Restart –Force
  }}