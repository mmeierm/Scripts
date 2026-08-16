Write-Output "Download App1"
If (!(Test-Path C:\Temp\))
{
New-Item -ItemType Directory -Path "C:\Temp\" -Force
}
Start-Process -FilePath "C:\Windows\System32\curl.exe" -ArgumentList '"<INSERTSASURLHERE>" -o "C:\Temp\App1.zip" --ssl-no-revoke' -Wait
Write-Output "Extract App1"
Expand-Archive -Path 'C:\Temp\App1.zip' -DestinationPath 'C:\Temp\App1' -Force
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
Write-Output "Install App1"
Start-Process -FilePath "C:\Temp\App1\Deploy-Application.exe" -Wait -passThru
