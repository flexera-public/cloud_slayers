[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$CommonName = "$($env:COMPUTERNAME)"
$thumbprint = (Get-ChildItem Cert:\LocalMachine\My\* | Where-Object { $_.Subject -eq "CN=$CommonName" }).Thumbprint
Write-Output $thumbprint | out-file c:\windows\temp\thumb.txt -encoding ASCII
