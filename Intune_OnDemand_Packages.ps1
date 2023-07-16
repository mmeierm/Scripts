    ##*===============================================
    ##* VARIABLE DECLARATION
    ##*===============================================

	[string]$MikeMDM_OnDemand_Key = '' #appname
    [string]$InstalledBy = (Get-WmiObject -class win32_process -ComputerName 'localhost' | Where-Object name -Match explorer).getowner().user | Select-Object -Unique
    [string]$InstalledOn = Get-Date -Format "dd.MM.yyyy - H:mm:ss"
    [string]$InstalledFrom = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent

    ##*===============================================
    ##* Perform Installation tasks here
    ##*===============================================
    ## <Perform Installation tasks here>



#Write MikeMDM Branding
##=====================
if ((Test-path "HKLM:\SOFTWARE\MikeMDM\") -eq $false)
{
New-Item -Path "HKLM:\SOFTWARE\" -Name "MikeMDM"
}
if ((Test-path "HKLM:\SOFTWARE\MikeMDM\Intune_OnDemand_Packages") -eq $false)
{
New-Item -Path "HKLM:\SOFTWARE\MikeMDM\" -Name "Intune_OnDemand_Packages"
}

if ((Test-Path "HKLM:\SOFTWARE\MikeMDM\Intune_OnDemand_Packages\$MikeMDM_OnDemand_Key") -eq $false)
    {
    
    New-Item -Path "HKLM:\SOFTWARE\MikeMDM\Intune_OnDemand_Packages\" -Name "$MikeMDM_OnDemand_Key"
    New-ItemProperty -Path "HKLM:\SOFTWARE\MikeMDM\Intune_OnDemand_Packages\$MikeMDM_OnDemand_Key" -Name "InstalledBy" -Value "$InstalledBy"  -PropertyType "String"
    New-ItemProperty -Path "HKLM:\SOFTWARE\MikeMDM\Intune_OnDemand_Packages\$MikeMDM_OnDemand_Key" -Name "InstalledOn" -Value "$InstalledOn"  -PropertyType "String"
    New-ItemProperty -Path "HKLM:\SOFTWARE\MikeMDM\Intune_OnDemand_Packages\$MikeMDM_OnDemand_Key" -Name "InstalledFrom" -Value "$InstalledFrom"  -PropertyType "String"
    }


####### Create and run scheduled task to remove all brandings for Intune_OnDemand_Packages

#check if scheduled task does already exist
if (Get-ScheduledTask -TaskName "Intune_OnDemand_Packages - Clean Branding" -ErrorAction SilentlyContinue)

#scheduled task exists, just run it
{
Start-ScheduledTask -TaskName "Intune_OnDemand_Packages - Clean Branding"
write-host "scheduled task already exists - it has been run successfully"
}

else

#scheduled task does not exist; create and run
{

$MyScriptBlockString=@"
#script to delete all branding keys from Intune_OnDemand_Packages as well as short term releases
Start-Sleep -seconds 300
Remove-Item -Path "HKLM:\SOFTWARE\MikeMDM\Intune_OnDemand_Packages\*"
write-host "removed all Intune_OnDemand_Packages brandings"

Exit 0
"@


$script = [System.Convert]::ToBase64String([System.Text.Encoding]::UNICODE.GetBytes($MyScriptBlockString))
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-encodedcommand $script -NoProfile -NoLogo -NonInteractive"
$principal = New-ScheduledTaskPrincipal "NT AUTHORITY\SYSTEM"
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -Compatibility V1 -DontStopIfGoingOnBatteries -DontStopOnIdleEnd
$trigger = New-ScheduledTaskTrigger -AtStartup
$task = New-ScheduledTask -Action $action -Settings $settings -Description "cleans up all MikeMDM brandings for Intune_OnDemand_Packages" -Principal $principal -Trigger $Trigger
Register-ScheduledTask -TaskName "Intune_OnDemand_Packages - Clean Branding" -InputObject $task | Out-Null



Start-ScheduledTask -TaskName "Intune_OnDemand_Packages - Clean Branding"
write-host "scheduled task was not there - it has been created and run"

}


 