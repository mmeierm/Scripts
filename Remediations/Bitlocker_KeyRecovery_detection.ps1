### detection script ###
### look for Bitlocker Recovery Key Backup events of Systemdrive

try
{
    ### obtain protected system volume
    $BLSysVolume = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop
    $BLRecoveryProtector = $BLSysVolume.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' } -ErrorAction Stop
    $BLprotectorguid = $BLRecoveryProtector.KeyProtectorId


    ### obtain backup event for System drive
    $BLBackupEvent = Get-WinEvent -ProviderName Microsoft-Windows-BitLocker-API -FilterXPath "*[System[(EventID=845)] and EventData[Data[@Name='ProtectorGUID'] and (Data='$BLprotectorguid')]]" -MaxEvents 1 -ErrorAction Stop

    # Check for returned values, if null, write output and exit 1
    if ($BLBackupEvent -gt $null) 
    {
	    # Write eventmessage and set exit success
	    Write-Output $BLBackupEvent.Message
	    Exit 0
    }
    else 
    {
	    Write-Output "Key-Backup Event for Bitlocker System drive not found"
	    Exit 1
    }
}
catch 
{
    $errMsg = $_.Exception.Message
    Write-Output $errMsg
    exit 1
}
