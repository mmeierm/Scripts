### remediation script ###
### backup recovery key of systemdrive

try{

    ### obtain protected system volume
    $BLSysVolume = Get-BitLockerVolume -MountPoint $env:SystemDrive
    $BLRecoveryProtector = $BLSysVolume.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }
    $BLprotectorguid = $BLRecoveryProtector.KeyProtectorId

    # Backup sysdrive recovery key to AAD
    BackuptoAAD-BitLockerKeyProtector -MountPoint $env:SystemDrive -KeyProtectorId $BLRecoveryProtector.KeyProtectorID -ErrorAction Stop
    Exit 0
}
catch
{
    $errMsg = $_.Exception.Message
    Write-Output $errMsg
    exit 1
}

