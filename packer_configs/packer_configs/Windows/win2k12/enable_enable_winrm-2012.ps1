$filename = "enable_winrm.ps1";
$link = "https://privatecloudtools.s3.amazonaws.com/enable_winrm.ps1";
$dstDir = "C:\";
$remotePath = Join-Path $dstDir $filename;
$client = New-Object System.Net.Webclient
$client.Proxy = $null
$client.downloadfile($link, $remotePath);

$filename = "SetupComplete2.cmd";
$link = "https://privatecloudtools.s3.amazonaws.com/SetupComplete.cmd";
$dstDir = "C:\Windows\OEM\";
$remotePath = Join-Path $dstDir $filename;
$client = New-Object System.Net.Webclient
$client.Proxy = $null
$client.downloadfile($link, $remotePath);
