#Storage account parameters
$AzCopyURI = "<URL to AZCopy.exe here>"
$URI="<URL to Folder with SAS Token>"

#Create Folder to collect Logs
$Path = New-Item -Path "C:\Windows\Temp\$env:COMPUTERNAME" -ItemType Directory -ErrorAction SilentlyContinue

#Collect W365 Client Logs
    $Users=(Get-Childitem C:\Users).FullName
    foreach ($User in $Users)
    {
    If ($User -ne "C:\Users\defaultuser0" -and $User -ne "C:\Users\Public")
        {
        try
            {
            $Useraccount = $User.Split('\')[-1]
            $Diagpath = Join-Path $User "AppData\Local\Temp\DiagOutputDir"
            Compress-Archive -Path $Diagpath -DestinationPath "$Path\$Useraccount"
            }
        catch
            {
            }
        }
    }

#Compress Logs to zip
Compress-Archive -Path "C:\Windows\Temp\$env:COMPUTERNAME" -DestinationPath "C:\Windows\Temp\$env:COMPUTERNAME.zip"
$ZipLog = "C:\Windows\Temp\$env:COMPUTERNAME.zip"

#Download AzCopy Tool from Blob Storage

If(!(Test-Path "C:\Windows\Temp\AzCopy.exe"))
{
Invoke-WebRequest $AzCopyURI -OutFile "C:\Windows\Temp\AzCopy.exe"
}

#Upload Logfiles
Start-Process -FilePath "C:\Windows\Temp\AzCopy.exe" -ArgumentList "copy $ZipLog $URI" -Wait

#CleanUp
Remove-Item -Path "C:\Windows\Temp\$env:COMPUTERNAME" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "C:\Windows\Temp\$env:COMPUTERNAME.zip" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "C:\Windows\Temp\AzCopy.exe" -Force -ErrorAction SilentlyContinue
