Write-Output "Download App2"
If (!(Test-Path C:\Temp\))
{
New-Item -ItemType Directory -Path "C:\Temp\" -Force
}
Start-Process -FilePath "C:\Windows\System32\curl.exe" -ArgumentList '"<INSERTSASURLHERE>" -o "C:\Temp\App2.zip" --ssl-no-revoke' -Wait
Write-Output "Extract App2"
Expand-Archive -Path 'C:\Temp\App2.zip' -DestinationPath 'C:\Temp\App2' -Force
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
Write-Output "Install App2"
Start-Process -FilePath "C:\Temp\App2\Deploy-Application.exe" -passThru
While((Get-Process "Deploy-Application" -ErrorAction SilentlyContinue) -cne $null)
    {
        Write-Host "Installing App2..."
        Start-Sleep -s 30
    }
