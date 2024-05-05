#Enable private Store only
$regpath="Software\Policies\Microsoft\WindowsStore\"
$name="RequirePrivateStoreOnly"
$value=1

#Registry Detection Template: Current logged on User

#Get SID of current interactive users
$CurrentLoggedOnUser = (Get-CimInstance win32_computersystem).UserName
if (-not ([string]::IsNullOrEmpty($CurrentLoggedOnUser))) {
    $AdObj = New-Object System.Security.Principal.NTAccount($CurrentLoggedOnUser)
    $strSID = $AdObj.Translate([System.Security.Principal.SecurityIdentifier])
    $UserSid = $strSID.Value
} else {
    $UserSid = $null
}

New-PSDrive -PSProvider Registry -Name "HKU" -Root HKEY_USERS | Out-Null
    $regkey = "HKU:\$UserSid\$regpath"


If (!(Test-Path $regkey))
{
New-Item -Path $regkey -ErrorAction stop
}

if (!(Get-ItemProperty -Path $regkey -Name $name -ErrorAction SilentlyContinue))
{
New-ItemProperty -Path $regkey -Name $name -Value $value -PropertyType DWORD -ErrorAction stop
write-output "remediation complete"
Remove-PSDrive -Name "HKU" | Out-Null
exit 0
}

set-ItemProperty -Path $regkey -Name $name -Value $value -ErrorAction stop
write-output "remediation complete"
Remove-PSDrive -Name "HKU" | Out-Null
exit 0

