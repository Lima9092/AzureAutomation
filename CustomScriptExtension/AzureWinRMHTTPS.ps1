# Ensure PS remoting is enabled, although this is enabled by default for Azure VMs 
Enable-PSRemoting -Force

# Create rule in Windows Firewall
New-NetFirewallRule `
    -Name "Windows Remote Management (HTTPS-In)" `
    -DisplayName "Windows Remote Management (HTTPS-In)" `
    -Enabled True `
    -Profile "Any" `
    -Action "Allow" `
    -Direction "Inbound" `
    -LocalPort 5986 `
    -Protocol "TCP"   

# Create Self Signed certificate and store thumbprint 
$DNSName = "$env:COMPUTERNAME"
$thumbprint = (New-SelfSignedCertificate -DnsName "$DNSName" -CertStoreLocation Cert:\LocalMachine\My).Thumbprint

# Run WinRM configuration on command line. DNS name set to computer hostname, you may wish to use a FQDN 
$cmd = "winrm create winrm/config/Listener?Address=*+Transport=HTTPS @{Hostname=""$DNSName""; CertificateThumbprint=""$thumbprint""}" 
cmd.exe /C $cmd