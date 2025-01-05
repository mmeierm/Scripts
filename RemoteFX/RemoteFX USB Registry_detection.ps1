# Check registry key for fUsbRedirectionEnableMode
If(!((Get-ItemProperty "HKLM:\Software\Policies\Microsoft\Windows NT\Terminal Services\Client").fUsbRedirectionEnableMode -eq "2"))
{
write-output "Key missing -> Need to remediate"
exit 1
}

# Check registry key for UpperFilters
If(!((Get-ItemProperty "HKLM:\System\CurrentControlSet\Control\Class\{36fc9e60-c465-11cf-8056-444553540000}").UpperFilters -contains "TsUSBFlt"))
{
write-output "Key missing -> Need to remediate"
exit 1
}

# Check registry key for BootFlags
If(!((Get-ItemProperty "HKLM:\System\CurrentControlSet\Services\TsUsbFlt").BootFlags -eq "4"))
{
write-output "Key missing -> Need to remediate"
exit 1
}

# Check registry key for EnableDiagnosticMode
If(!((Get-ItemProperty "HKLM:\System\CurrentControlSet\Services\usbhub\hubg").EnableDiagnosticMode -eq "2147483648"))
{
write-output "Key missing -> Need to remediate"
exit 1
}
Write-Output "All Keys correct -> Noting to do"
exit 0
