@ECHO OFF && SETLOCAL && SETLOCAL ENABLEDELAYEDEXPANSION && SETLOCAL ENABLEEXTENSIONS

ECHO SetupComplete2.cmd BEGIN >> %windir%\Panther\WaSetup.log

TITLE SETUP COMPLETE
powershell -ExecutionPolicy UnRestricted -File C:\enable_winrm.ps1 >> c:\Windows\Panther\WaSetup.txt

REM execute unattend script
cscript %SystemRoot%\OEM\idk.wsf //Job:setup //NoLogo //B /ConfigurationPass:oobeSystem >> %windir%\Panther\WaSetup.log

ECHO SetupComplete2.cmd END >> %windir%\Panther\WaSetup.log
