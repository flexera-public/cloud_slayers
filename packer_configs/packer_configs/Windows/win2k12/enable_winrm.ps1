# Enable WinRM with HTTPS using a self-signed SSL certificate
Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System -Name LocalAccountTokenFilterPolicy -Type DWord -Value 1
Start-Service WinRM

$ErrorActionPreference = 'Stop'
$WinRMHTTPSPort = 5986
$CommonName = "$($env:COMPUTERNAME)"
$certsBefore = Get-ChildItem Cert:\LocalMachine\My\*

if (-not (Get-Item Cert:\LocalMachine\My\* | Where-Object { $_.Subject -eq "CN=$CommonName" })) {
  Write-Host "Certificate with subject `"$CommonName`" does not exist. Generating it."

  $name = New-Object -ComObject 'X509Enrollment.CX500DistinguishedName.1'
  $name.Encode("CN=$CommonName", 0)

  $key = New-Object -ComObject 'X509Enrollment.CX509PrivateKey.1'
  $key.ProviderName = 'Microsoft RSA SChannel Cryptographic Provider'
  $key.KeySpec = 1
  $key.Length = 1024
  $key.SecurityDescriptor = 'D:PAI(A;;0xd01f01ff;;;SY)(A;;0xd01f01ff;;;BA)(A;;0x80120089;;;NS)'
  $key.MachineContext = 1
  $key.ExportPolicy = 1
  $key.Create()

  $serverauthoid = New-Object -ComObject 'X509Enrollment.CObjectId.1'
  $serverauthoid.InitializeFromValue('1.3.6.1.5.5.7.3.1')
  $ekuoids = New-Object -ComObject 'X509Enrollment.CObjectIds.1'
  $ekuoids.Add($serverauthoid)
  $ekuext = New-Object -ComObject 'X509Enrollment.CX509ExtensionEnhancedKeyUsage.1'
  $ekuext.InitializeEncode($ekuoids)

  $notBefore = (Get-Date).ToUniversalTime()
  $notAfter = $notBefore.AddDays(90)

  $cert = New-Object -ComObject 'X509Enrollment.CX509CertificateRequestCertificate.1'
  $cert.InitializeFromPrivateKey(2, $key, '')
  $cert.Subject = $name
  $cert.Issuer = $name
  $cert.NotBefore = $notBefore
  $cert.NotAfter = $notAfter
  $cert.X509Extensions.Add($ekuext)
  $cert.Encode()

  $enrollment = New-Object -ComObject 'X509Enrollment.CX509Enrollment.1'
  $enrollment.InitializeFromRequest($cert)
  $enrollment.CertificateFriendlyName = 'RightScale WinRM'
  $certdata = $enrollment.CreateRequest(0)
  $enrollment.InstallResponse(2, $certdata, 0, '')

  Push-Location HKLM:\SOFTWARE\Microsoft\SystemCertificates\MY\Certificates
  $certsAfter = Get-ChildItem | Select-Object PSChildName
  foreach ($ca in $certsAfter) {
    $found = $true
    foreach ($cb in $certsBefore) {
      if ($cb.Thumbprint -eq $ca.PSChildName) {
        $found = $false
      }
    }
    if ($found) {
      $thumbprint = $ca.PSChildName
    }
  }
  Write-Host $thumbprint
  Pop-Location
} else {
  Write-Host "Certificate with subject `"$CommonName`" exists."
  $thumbprint = (Get-ChildItem Cert:\LocalMachine\My\* | Where-Object { $_.Subject -eq "CN=$CommonName" }).Thumbprint
}

if (-not $thumbprint) {
  throw 'Unable to find certificate thumbprint!'
}

$command = "winrm create winrm/config/Listener?Address=*+Transport=HTTPS @{Port=`"$WinRMHTTPSPort`";Hostname=`"$CommonName`";CertificateThumbprint=`"$thumbprint`"}"
Write-Host "Running command: $command"
& cmd /c $($command)

Write-Host 'Enumerating listeners:'
winrm enumerate winrm/config/listener
winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="2048"}'
winrm set winrm/config/service/auth '@{Basic="true"}'

netsh advfirewall firewall add rule name="RightScale WinRM" remoteip=any localport=$WinRMHTTPSPort action=allow protocol=tcp dir=in
