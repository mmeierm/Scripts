Write-Output "Download App3"
If (!(Test-Path C:\Temp\))
{
New-Item -ItemType Directory -Path "C:\Temp\" -Force
}

Invoke-WebRequest -Uri "https://aka.ms/downloadazcopy-v10-windows" -OutFile "C:\Temp\azcopy.zip"
Expand-Archive -Path 'C:\Temp\azcopy.zip' -DestinationPath 'C:\Temp' -Force
$azcopy=(gci C:\Temp\ azcopy.exe -Recurse).FullName
move-item $azcopy C:\Temp
Start-Process -FilePath "C:\Temp\azcopy.exe" -ArgumentList 'copy "<INSERTSASURLHERE>" "C:\Temp\App3.zip"' -Wait

Write-Output "Extract App3"
Expand-Archive -Path 'C:\Temp\App3.zip' -DestinationPath 'C:\Temp\App3' -Force
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
Write-Output "Install App3"
Start-Process -FilePath "C:\Temp\App3\Deploy-Application.exe" -Wait -passThru
