#Check if Wiregurad VPN is installed
$WireguardPath = Test-Path "C:\Program Files\WireGuard\wireguard.exe"

$regkey='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\'
$name="DisplayName"
$value="WireGuard"

If (Get-ChildItem -Path $regkey -Recurse -EA SilentlyContinue | Get-ItemProperty | Where-Object $name -like $value) 
{
    $WireguardARP = $true
} 

else 
{
    $WireguardARP = $false
} 

If ($WireguardPath -and $WireguardARP)
{
    $VPNInstalled = $true
}
else 
{
    $VPNInstalled = $false
}

#Search for unapproved Apps

$regkeyUser='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\'
$regkeySYS='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\'
$name="DisplayName"
$value="Google Chrome"

If (Get-ChildItem -Path $regkeySYS -Recurse -EA SilentlyContinue | Get-ItemProperty | Where-Object $name -like $value) 
{
    $NonApprovedApp = $true
}

elseif (Get-ChildItem -Path $regkeyUser -Recurse -EA SilentlyContinue | Get-ItemProperty | Where-Object $name -like $value) 
{
    $NonApprovedApp = $true
}

else 
{
    $NonApprovedApp = $false
} 
    


$hash = @{ VPNInstalled = $VPNInstalled; NonApprovedApp = $NonApprovedApp}
return $hash | ConvertTo-Json -Compress
