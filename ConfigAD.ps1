# Configure Active Directory
  $csv = import-csv AzureVMs.csv 
  $csv | foreach-object {
    $IPAddress = $_.'IPAddress'
    $Type = $_.'Type'
    $DomainName = $_.'DomainName'
    $DNSName = $_.'DNSName'
    $DC = $_.'DC'

    # Only perform Domain Controller tasks on Type = "Domain Controller"
    if ($Type -eq "Domain Controller") {

      # Set Credentials
      $UserName="labadmin"
      $Password="Password@123"| ConvertTo-SecureString -Force -AsPlainText
      $Credential=New-Object PSCredential($UserName,$Password)

      # Establish Remote PS Session and configure Domain Controller
      $session = New-PSSession -ComputerName $DNSName -Credential $Credential -UseSSL -SessionOption(New-PSsessionOption -SkipCACheck -SkipCNCheck)
        Invoke-command -Session $session {
          $SafePass="Password@123"| ConvertTo-SecureString -Force -AsPlainText
          Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
          Install-ADDSForest -DomainName $Using:DomainName -InstallDns -SafeModeAdministratorPassword $SafePass -Force
          }
    }
  
  # Wait for Domain Controllers to reboot
  Start-Sleep -s 300

    if ($Type -eq "Member Server") {

    # Set Credentials
    $UserName="labadmin"
    $Password="Password@123"| ConvertTo-SecureString -Force -AsPlainText
    $Credential=New-Object PSCredential($UserName,$Password)
    $DomUserName="$DomainName\labadmin"
    $DomPassword="Password@123"| ConvertTo-SecureString -Force -AsPlainText
    $DomCredential=New-Object PSCredential($UserName,$Password)

     # Establish Remote PS Session, add server/s to domain and restart
        $session = New-PSSession -ComputerName $DNSName -Credential $Credential -UseSSL -SessionOption(New-PSsessionOption -SkipCACheck -SkipCNCheck)
          Invoke-command -Session $session -script {
             Add-Computer –DomainName $using:DomainName -Credential $Using:DomCredential -Restart –Force
          }       
    }
  }