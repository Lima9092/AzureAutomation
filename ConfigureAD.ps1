$UserName = Read-Host "Enter administrator username for Azure VMs: (Cannot be 'admin' or 'administrator' in Azure)"
$Password = Read-Host "Enter administrator password for Azure VMs:" -AsSecureString
$DomUserName = "$DomainName\$UserName"
$DomPassword = $Password
$SafePass = Read-Host "Enter Safe Mode Administrator password for Domains in the Azure VM envinronment:" -AsSecureString

# Configure Active Directory
  $csv = import-csv AzureVMs.csv 
  $csv | foreach-object {
    $Type = $_.'Type'
    $DomainName = $_.'DomainName'
    $DNSName = $_.'DNSName'
    $DC = $_.'DC'

    # Only perform Domain Controller tasks on Type = "Domain Controller"
    if ($Type -eq "Domain Controller") {

      # Set Credentials
      $UserName = $UserName
      $Password = $Password | ConvertTo-SecureString -Force -AsPlainText
      $Credential = New-Object PSCredential($UserName,$Password)

      # Establish Remote PS Session and configure Domain Controller
      $session = New-PSSession -ComputerName $DNSName -Credential $Credential -UseSSL -SessionOption(New-PSsessionOption -SkipCACheck -SkipCNCheck)
        Invoke-command -Session $session {
          $SafePass = $Using:SafePass | ConvertTo-SecureString -Force -AsPlainText
          Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
          Install-ADDSForest -DomainName $Using:DomainName -InstallDns -SafeModeAdministratorPassword $SafePass -Force
          }
    }
  
# Wait for Domain Controllers to reboot
Start-Sleep -s 120

    if ($Type -eq "Member Server") {

    # Set Credentials
    $UserName = $UserName
    $Password = $Password | ConvertTo-SecureString -Force -AsPlainText
    $Credential=New-Object PSCredential($UserName,$Password)
    $DomUserName = $DomUserName 
    $DomPassword = $DomPassword | ConvertTo-SecureString -Force -AsPlainText
    $DomCredential = New-Object PSCredential($UserName,$Password)

     # Establish Remote PS Session, add server/s to domain and restart
        $session = New-PSSession -ComputerName $DNSName -Credential $Credential -UseSSL -SessionOption(New-PSsessionOption -SkipCACheck -SkipCNCheck)
          Invoke-command -Session $session {
             Add-Computer –DomainName $using:DomainName -Credential $Using:DomCredential -Restart –Force
          }       
    }
  }

# Wait for Servers to reboot
Start-Sleep -s 120

# Shutdown VMs
# Configure Active Directory
  $csv = import-csv AzureVMs.csv 
  $csv | foreach-object {
    $DNSName = $_.'DNSName'

     # Establish Remote PS Session and shutdown
        $session = New-PSSession -ComputerName $DNSName -Credential $Credential -UseSSL -SessionOption(New-PSsessionOption -SkipCACheck -SkipCNCheck)
          Invoke-command -Session $session {
             Stop-Computer
        }       
  }