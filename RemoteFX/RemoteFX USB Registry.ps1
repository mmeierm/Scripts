# Set registry key for fUsbRedirectionEnableMode
Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows NT\Terminal Services\Client" -Name "fUsbRedirectionEnableMode" -Value 2 -Type DWord

# Set registry key for UpperFilters
If ((Get-ItemProperty "HKLM:\System\CurrentControlSet\Control\Class\{36fc9e60-c465-11cf-8056-444553540000}\").UpperFilters)
{
    If ((Get-ItemProperty "HKLM:\System\CurrentControlSet\Control\Class\{36fc9e60-c465-11cf-8056-444553540000}\").UpperFilters -notcontains "TsUSBFlt")
    {

        # Writing a REG_MULTI_SZ value
        $upperFilters = (Get-ItemProperty "HKLM:\System\CurrentControlSet\Control\Class\{36fc9e60-c465-11cf-8056-444553540000}\").UpperFilters
        $upperFilters = $upperFilters + "TsUSBFlt"

        Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Class\{36fc9e60-c465-11cf-8056-444553540000}" -Name "UpperFilters" -Value $upperFilters -Type MultiString
    }
}
else
{

    # Writing a REG_MULTI_SZ value
    $upperFilters = @('TsUSBFlt')
    Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Class\{36fc9e60-c465-11cf-8056-444553540000}" -Name "UpperFilters" -Value $upperFilters -Type MultiString
}

# Set registry key for BootFlags
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\TsUsbFlt" -Name "BootFlags" -Value 4 -Type DWord

If(!(Test-Path -Path "HKLM:\System\CurrentControlSet\Services\usbhub\hubg"))
{
New-Item -Path "HKLM:\System\CurrentControlSet\Services\usbhub\hubg" -ErrorAction stop
}
# Set registry key for EnableDiagnosticMode
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\usbhub\hubg" -Name "EnableDiagnosticMode" -Value 0x80000000 -Type DWord
