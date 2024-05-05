#Enable private Store only
$regpath="Software\Policies\Microsoft\WindowsStore\"
$name="RequirePrivateStoreOnly"
$value=1

#Registry Detection Template: Current logged on User

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
            New-Item -Path $regkey -ErrorAction stop
        }

        if (!(Get-ItemProperty -Path $regkey -Name $name -ErrorAction SilentlyContinue))
        {
            New-ItemProperty -Path $regkey -Name $name -Value $value -PropertyType DWORD -ErrorAction stop
        }
        else 
        {
            set-ItemProperty -Path $regkey -Name $name -Value $value -ErrorAction stop
        }
    }

    
}

Remove-PSDrive -Name "HKU" | Out-Null
Exit 0
