#Enable private Store only
$regpath="Software\Policies\Microsoft\WindowsStore\"
$name="RequirePrivateStoreOnly"
$value=1

#Registry Detection Template: All Users

New-PSDrive -PSProvider Registry -Name "HKU" -Root HKEY_USERS | Out-Null
    $Users = (Get-ChildItem "HKU:" -Depth 0).Name

foreach ($User in $Users)
{
    If($User -ne "HKEY_USERS\S-1-5-18" -and $User -ne "HKEY_USERS\S-1-5-19" -and $User -ne "HKEY_USERS\S-1-5-20" -and $User -ne "HKEY_USERS\.DEFAULT" -and $User -notlike "*_Classes")
    {
        $regkey="HKU:\$User\$regpath"
        If (!(Test-Path $regkey))
        {
            Write-Output 'RegKey not available - remediate'
            Remove-PSDrive -Name "HKU" | Out-Null
            Exit 1
        }


        $check=(Get-ItemProperty -path $regkey -name $name -ErrorAction SilentlyContinue).$name
        if ($check -eq $value){
            write-output 'setting ok - no remediation required for this user'
        }

        else {
            write-output 'value not ok, no value or could not read - go and remediate'
            Remove-PSDrive -Name "HKU" | Out-Null
            Exit 1
        }
    }

    
}

Remove-PSDrive -Name "HKU" | Out-Null
Exit 0

