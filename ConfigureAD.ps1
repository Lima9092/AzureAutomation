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

# Set Safe Mode Admin Credentials
do {
Write-Host "`nEnter Safe Mode Administrator password for Domains`n"
$PreSafePass = Read-Host "Password" -AsSecureString
$SafePass = Read-Host "Confirm Password" -AsSecureString
$PreSafePass_text = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($PreSafePass))
$SafePass_text = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($SafePass))
}
while ($PreSafePass_text -ne $SafePass_text)
Write-Host "`nPassword succesffuly set"

# Configure Active Directory
  $csv = import-csv AzureVMs.csv 
  $csv | foreach-object {
    $Type = $_.'Type'
    $DomainName = $_.'DomainName'
    $DNSName = $_.'DNSName'
    $DNSIP = $_.'DNSIP'
    $DC = $_.'DC'
    $DomUserName = "$DomainName\$UserName"
    $DomPassword = $Password

    # Only perform Domain Controller tasks on Type = "Domain Controller"
    if ($Type -eq "Domain Controller") {

      # Set Credentials
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
    $Credential=New-Object PSCredential($UserName,$Password)
    $DomCredential = New-Object PSCredential($DomUserName,$DomPassword)
  
     # Establish Remote PS Session, add server/s to domain and restart
        $session = New-PSSession -ComputerName $DNSName -Credential $Credential -UseSSL -SessionOption(New-PSsessionOption -SkipCACheck -SkipCNCheck)
          Invoke-command -Session $session {
             $nicif = Get-NetAdapter | Select -ExpandProperty IfIndex
             Set-DNSClientServerAddress –interfaceIndex $nicif –ServerAddresses (“$Using:DNSIP”) 
             Add-Computer –DomainName $using:DomainName -LocalCredential $Using:Credential -DomainCredential $Using:DomCredential -Restart –Force
          }       
    }
  }