#Wifi Profile "Added by company policy"
$WifiProfileName = "PlaygroundBul-Wifi3"
$Path = "C:\ProgramData\Microsoft\Wlansvc\Profiles\Interfaces"
$interfaces=Get-ChildItem $Path
foreach ($interface in $interfaces)
    {
        $profiles = Get-ChildItem $interface.FullName
        foreach ($profile in $profiles)
        {
        $xml = get-content $profile.fullname
        if ($xml -match $WifiProfileName)
            {
            #write-host "found interface $($interface.Name)"
            #write-host "found profile $($profile.name)"
            $profileguid = $($profile.name).Split('.')[0]
            $reg = "HKLM:\SOFTWARE\Microsoft\WlanSvc\Interfaces\$($interface.Name)\Profiles\$profileguid\MetaData"
            If (!(Get-ItemProperty $reg -Name "Connection Type")) 
                {
                New-ItemProperty -Path $reg -Name "Connection Type" -PropertyType Binary -Value ([byte[]](0x08,0x00,0x00,0x00))
                }
            }
        }
    }
