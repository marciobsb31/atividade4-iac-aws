<powershell>
$ErrorActionPreference = "Stop"

Enable-PSRemoting -Force
Set-Service -Name WinRM -StartupType Automatic
Start-Service -Name WinRM

$certificate = New-SelfSignedCertificate `
  -DnsName $env:COMPUTERNAME `
  -CertStoreLocation "Cert:\LocalMachine\My"

$httpsListeners = Get-ChildItem -Path WSMan:\localhost\Listener |
  Where-Object { $_.Keys -match "Transport=HTTPS" }

foreach ($listener in $httpsListeners) {
  Remove-Item -Path $listener.PSPath -Recurse -Force
}

New-Item `
  -Path WSMan:\localhost\Listener `
  -Transport HTTPS `
  -Address * `
  -CertificateThumbPrint $certificate.Thumbprint `
  -Force

Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $true
Set-Item -Path WSMan:\localhost\Service\AllowUnencrypted -Value $false

New-NetFirewallRule `
  -DisplayName "WinRM HTTPS (5986)" `
  -Direction Inbound `
  -Protocol TCP `
  -LocalPort 5986 `
  -Action Allow `
  -Profile Any
</powershell>
