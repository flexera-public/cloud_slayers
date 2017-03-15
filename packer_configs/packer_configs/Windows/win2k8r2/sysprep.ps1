"& $Env:SystemRoot\System32\Sysprep\Sysprep.exe /oobe /generalize /quiet; echo Sysprep Exit Code is $errorlevel"
Write-Host "Powershell Exit Code is $LastExitCode, $?"
