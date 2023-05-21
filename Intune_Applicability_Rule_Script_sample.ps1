#The exit code from the PS should match with the value you set in Intune - Means, the requirement is met and the application will install.

#Enter Application Details:
#==========================
$AppName = "7-Zip"
$LatestVersion = "22.01.00.0"

$VersionReg32 = Get-ChildItem -Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall" | Get-ItemProperty | Where-Object {$_.DisplayName -match $AppName}
$VersionReg64 = Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" | Get-ItemProperty | Where-Object {$_.DisplayName -match $AppName}

If(($VersionReg32 -eq $null) -and ($VersionReg64 -eq $null)){
    #Write-Host "Previous Version not found, Deployment is not Applicable"
    Write-Output "0"
    Exit
}
Else{

    If(($VersionReg32.DisplayVersion -ne $null) -and ($VersionReg32.DisplayVersion -lt $LatestVersion)){
        #Write-Host "Lower Version of the app found, Deployment Applicable"
        Write-Output "1"
        Exit
    }
    Elseif(($VersionReg64.DisplayVersion -ne $null) -and ($VersionReg64.DisplayVersion -lt $LatestVersion)){
        #Write-Host "Lower Version of the app found - 64, Deployment Applicable"
        Write-Output "1"
        Exit
    }
    Else{
        #Write-Host "Updated Version Found, Deployment Not Applicaple"
        Write-Output "0"
        Exit
    }

}

