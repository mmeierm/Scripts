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
Write-Output 'RegKey not available - remediate'
Remove-PSDrive -Name "HKU" | Out-Null
Exit 1
}


$check=(Get-ItemProperty -path $regkey -name $name -ErrorAction SilentlyContinue).$name
if ($check -eq $value){
write-output 'setting ok - no remediation required'
Remove-PSDrive -Name "HKU" | Out-Null
Exit 0
}

else {
write-output 'value not ok, no value or could not read - go and remediate'
Remove-PSDrive -Name "HKU" | Out-Null
Exit 1
}
