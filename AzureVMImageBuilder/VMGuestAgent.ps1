Write-Output "Disable Azure Guest Agent Installation during SetupComplete"
Rename-Item -Path "C:\Windows\OEM" -NewName "OEM.bak" -Force
