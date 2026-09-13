#Region Notification Functions
function Add-NotificationApp {
    <#
    .SYNOPSIS
    Function to verify and register toast notification app in registry as system

    .DESCRIPTION
    This function must be run as system and registers the toast notification app with your own name and icon. 

    .PARAMETER AppID
    The AppID (Name) to be used to the toast notification. Example: MikeMDM.SystemToast.UpdateNotification

    .PARAMETER AppDisplayName
    The Display Name for your  toast notification app. Example: MikeMDM

    .PARAMETER IconUri
    The path to the icon shown in the Toast Notification. Expample: %SystemRoot%\system32\@WindowsUpdateToastIcon.png

    .PARAMETER ShowInSettings
    Default Value 0 is recommended. Not required. But can be change to 1. Not recommended for this solution
    #>    
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]$AppID,
        [Parameter(Mandatory=$true)]$AppDisplayName,
        [Parameter(Mandatory=$true)]$IconUri,
        [Parameter(Mandatory=$false)][int]$ShowInSettings = 0
    )
    # Verify if PSDrive Exists
    $HKCR = Get-PSDrive -Name HKCR -ErrorAction SilentlyContinue
    If (!($HKCR))
    {
        New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT -Scope Script
    }
    $AppRegPath = "HKCR:\AppUserModelId"
    $RegPath = "$AppRegPath\$AppID"
    # Verify if App exists in registry
    If (!(Test-Path $RegPath))
    {
        Write-EventLog -LogName $EventLogName -EntryType Information -EventId 8001 -Source $EventLogSource -Message "Toast Notification App does not exists - creating"
        $null = New-Item -Path $AppRegPath -Name $AppID -Force
    }
    # Verify Toast App Displayname
    $DisplayName = Get-ItemProperty -Path $RegPath -Name DisplayName -ErrorAction SilentlyContinue | Select-Object -ExpandProperty DisplayName -ErrorAction SilentlyContinue
    If ($DisplayName -ne $AppDisplayName)
    {
        $null = New-ItemProperty -Path $RegPath -Name DisplayName -Value $AppDisplayName -PropertyType String -Force
        Write-EventLog -LogName $EventLogName -EntryType Information -EventId 8001 -Source $EventLogSource -Message "Toast notification app $($DisplayName) created"
    }
    # Verify Show in settings value
    $ShowInSettingsValue = Get-ItemProperty -Path $RegPath -Name ShowInSettings -ErrorAction SilentlyContinue | Select-Object -ExpandProperty ShowInSettings -ErrorAction SilentlyContinue
    If ($ShowInSettingsValue -ne $ShowInSettings)
    {
        $null = New-ItemProperty -Path $RegPath -Name ShowInSettings -Value $ShowInSettings -PropertyType DWORD -Force
        Write-EventLog -LogName $EventLogName -EntryType Information -EventId 8001 -Source $EventLogSource -Message "Toast notification app settings applied"
    }
    # Verify toast icon value
    $IconSettingsValue = Get-ItemProperty -Path $RegPath -Name IconUri -ErrorAction SilentlyContinue | Select-Object -ExpandProperty IconUri -ErrorAction SilentlyContinue
    If ($IconSettingsValue -ne $IconUri)
    {
        $null = New-ItemProperty -Path $RegPath -Name IconUri -Value $IconUri -PropertyType ExpandString -Force
        Write-EventLog -LogName $EventLogName -EntryType Information -EventId 8001 -Source $EventLogSource -Message "Toast notification app icon set"
    }
    # Clean up
    Remove-PSDrive -Name HKCR -Force
}#endfunction
function Add-ToastLaunchVDIManagerProtocolHandler{
    <#
    .SYNOPSIS
    Function to add the protocol handler for your toast notifications

    .DESCRIPTION
    This function must be run as system and registers the protocal handler for toast. 
    #>   
    New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT -ErrorAction SilentlyContinue | out-null

        #create handler
        Remove-Item 'HKCR:\VDIManagerLaunch' -Force -recurse

        New-Item 'HKCR:\VDIManagerLaunch' -Force
        Set-Itemproperty 'HKCR:\VDIManagerLaunch' -Name '(DEFAULT)' -Value 'url:VDIManagerLaunch' -Force
        Set-Itemproperty 'HKCR:\VDIManagerLaunch' -Name 'URL Protocol' -Value '' -Force
        New-Itemproperty -path 'HKCR:\VDIManagerLaunch' -PropertyType DWORD -Name 'EditFlags' -Value 2162688
        New-Item 'HKCR:\VDIManagerLaunch\Shell\Open\command' -Force
        Set-Itemproperty 'HKCR:\VDIManagerLaunch\Shell\Open\command' -Name '(DEFAULT)' -Value "`"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`" -file `"$PSScriptRoot\VDI-Manager-GUI.ps1`"" -Force    
    Remove-PSDrive -Name HKCR -Force -ErrorAction SilentlyContinue
}#endfunction
function Invoke-ToastNotification {
    Param(
        [Parameter(Mandatory=$false)]$FullName,
        [parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[array]$ToastSettings,
        [Parameter(Mandatory=$true)]$AppID,
        [Parameter(Mandatory=$true)]$Scenario
    )

$MyScriptBlockString = "
function Start-ToastNotification {
    `$Load = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
    `$Load = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]
    # Load the notification into the required format
    `$ToastXML = New-Object -TypeName Windows.Data.Xml.Dom.XmlDocument
    `$ToastXML.LoadXml(`$Toast.OuterXml)
    # Display the toast notification
    try {
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier(`"$AppID`").Show(`$ToastXml)
    }
    catch { 
        Write-Output -Message 'Something went wrong when displaying the toast notification' -Level Warn     
        Write-EventLog -LogName $EventLogName -EntryType Warning -EventId 8002 -Source $EventLogSource -Message `"Something went wrong when displaying the toast notification`"
    }
    Write-EventLog -LogName $EventLogName -EntryType Information -EventId 8001 -Source $EventLogSource -Message `"Toast Notification successfully delivered to logged on user`"
}
[xml]`$Toast = @`"
<toast scenario=`"$Scenario`">
    <visual>
    <binding template=`"ToastGeneric`">
        <image id=`"1`" placement=`"appLogoOverride`" hint-crop=`"circle`" src=`"$($ToastSettings.LogoImage)`"/>
        <text placement=`"attribution`">$($ToastSettings.AttributionText)</text>
        <text>$($ToastSettings.HeaderText)</text>
        <group>
            <subgroup>
                <text hint-style=`"title`" hint-wrap=`"true`" >$($ToastSettings.TitleText)</text>
            </subgroup>
        </group>
        <group>
            <subgroup>     
                <text hint-style=`"body`" hint-wrap=`"true`" >$($ToastSettings.BodyText1)</text>
            </subgroup>
        </group>
        <group>
            <subgroup>     
                <text hint-style=`"body`" hint-wrap=`"true`" >$($ToastSettings.BodyText2)</text>
            </subgroup>
        </group>
    </binding>
    </visual>
    <actions>
	<action activationType=`"protocol`" arguments=`"VDIManagerLaunch:`" content=`"$($ToastSettings.ActionButtonContent)`"/>
    </actions>
    <audio src=`"ms-winsoundevent:Notification.Default`"/>
</toast>
`"@
Start-ToastNotification
"


$EncodedScript = [System.Convert]::ToBase64String([System.Text.Encoding]::UNICODE.GetBytes($MyScriptBlockString))

#Set Unique GUID for the Toast
If (!($ToastGUID)) {
    $ToastGUID = ([guid]::NewGuid()).ToString().ToUpper()
}
$Task_TimeToRun = (Get-Date).AddSeconds(10).ToString('s')
$Task_Expiry = (Get-Date).AddSeconds(120).ToString('s')
$Task_Trigger = New-ScheduledTaskTrigger -Once -At $Task_TimeToRun
$Task_Trigger.EndBoundary = $Task_Expiry
$Task_Principal = New-ScheduledTaskPrincipal -GroupId "S-1-5-32-545" -RunLevel Limited
$Task_Settings = New-ScheduledTaskSettingsSet -Compatibility V1 -DeleteExpiredTaskAfter (New-TimeSpan -Seconds 600) -AllowStartIfOnBatteries
$Task_Action = New-ScheduledTaskAction -Execute "C:\WINDOWS\system32\WindowsPowerShell\v1.0\PowerShell.exe" -Argument "-NoProfile -WindowStyle Hidden -EncodedCommand $EncodedScript"

$New_Task = New-ScheduledTask -Description "Toast_Notification_$($ToastGuid) Task for user notification" -Action $Task_Action -Principal $Task_Principal -Trigger $Task_Trigger -Settings $Task_Settings
Register-ScheduledTask -TaskName "Toast_Notification_$($ToastGuid)" -InputObject $New_Task | Out-Null
Write-EventLog -LogName $EventLogName -EntryType Information -EventId 8001 -Source $EventLogSource -Message "Toast Notification Task created for logged on user: Toast_Notification_$($ToastGuid)"
}
#endfunction
#Endregion Notification Functions


#Download Versions.json
$versionJson = Get-Content -Path "C:\ProgramData\VDI-Manager\VDI-Manager-Versions.json" -Raw | ConvertFrom-Json
$vmInventory = Get-Content -Path "C:\ProgramData\VDI-Manager\VDI-Manager-VMs.json" -Raw | ConvertFrom-Json

#endregion get current versions

$displayArray = @($vmInventory | ForEach-Object {
    $vm = $_
    $versionDetails = $null
    $expiryDate = "Unknown VM / Version"
    $update = $null
    $downloadURL = $null

    if ($vm.VMName) {
        $versionKey = $versionJson.PSObject.Properties | Where-Object { $_.Name -eq $vm.VMName } | Select-Object -First 1
        if ($versionKey) {
            $versionDetails = $versionKey.Value
            $expiryDate = $versionDetails.Expiry
            $update = $versionDetails.ReplacedBy

            if ($update -and $update -ne "-") {
                $replacementKey = $versionJson.PSObject.Properties | Where-Object { $_.Name -eq $update } | Select-Object -First 1
                if ($replacementKey -and $replacementKey.Value.Download -ne "-") {
                    $downloadURL = $replacementKey.Value.Download
                }
            }
        }
    }

    [PSCustomObject]@{
        VMName = $vm.VMName
        Type = $vm.Type
        User = $vm.User
        LastBootTimeUTC = $vm.LastBootTimeUTC
        ExpiryDate = $expiryDate
        Update = $update
        DownloadURL = $downloadURL
        InventoryDetails = $vm
        VersionDetails = $versionDetails
    }
} | Where-Object { $_.VMName })


#region Decalarations 
# Create and define Eventlog for logging
$Script:ErrorActionPreference = "SilentlyContinue" 
$Script:EventLogName = 'MikeMDM-VDIManager'
$Script:EventLogSource = 'VDI-Manager'
New-EventLog -LogName $EventLogName -Source $EventLogSource -ErrorAction SilentlyContinue
# Set Toast Notification App Parameters 
$Script:AppID = "MikeMDM.SystemToast.VDIManagerNotification"
$Script:AppDisplayName = "MikeMDM VDI Manager"
$Script:ToastMediafolder = "$PSScriptRoot\ToastMedia"
$IconPath= Join-path $ToastMediafolder "Icon.png"
$Script:IconUri = $IconPath
$Script:Scenario = 'reminder' # <!-- Possible values are: reminder | short | long | alarm
$Script:RegPath = 'HKLM:\SOFTWARE\MikeMDM\VDI Manager Notifications' # Registry path for status messages

#EndRegion Declarations 


#Check conditions

$UpdateVMs = ($displayArray | Where-Object -Property Update -ne $null | Where-Object -Property Update -ne "-" | Select-Object -ExpandProperty VMName) 
$ExpiredVMs = ($displayArray | Where-Object -Property ExpiryDate -ne $null | Where-Object -Property ExpiryDate -ne "Unknown VM / Version" | Where-Object -Property ExpiryDate -lt (Get-Date -format o) | Select-Object -ExpandProperty VMName)
$StaleVMs = ($displayArray | Where-Object -Property LastBootTimeUTC -ne $null | Where-Object -Property LastBootTimeUTC -lt (Get-Date((Get-Date).AddMonths(-2)) -format o) | Select-Object -ExpandProperty VMName)
$AlertVMs = ($displayArray | Where-Object { $_.VersionDetails.Alert -eq "true" } | Select-Object -ExpandProperty VMName)

############################################## Stale VMs - Toast Notification for non-GUI mode ##############################################

If ($StaleVMs.Count -gt 0)
    {

    #Foreach stale VM, send a toast notification to the user

    #Set Toast Settings - Adjust to your own requirements - modification required
    $Script:ToastSettings = @{

        LogoImage = "$ToastMediafolder\ToastLogoImage.png"
        HeaderText = "VDI Manager Info" #Short Message Header
        AttributionText = "Stale VM detected" #Short Message small text

        TitleText = "Stale VM detected" #Long Message Header
        BodyText1 = "The following VM(s) weren't booted since more than 2 months"#Long Message Text Line
        BodyText2 = $StaleVMs | Out-String #Long Message Text Line
        ActionButtonContent = "Open VDI Manager" #Text for Action Button
    }
    # Adding and verifying Toast Application and Protocol Handler
    Add-NotificationApp -AppID $AppID -AppDisplayName $AppDisplayName -IconUri $IconUri | Out-Null
    Add-ToastLaunchVDIManagerProtocolHandler | Out-Null

        Invoke-ToastNotification -ToastSettings $ToastSettings -AppID $AppID -Scenario $Scenario
    }

############################################## Updated VMs - Toast Notification for non-GUI mode ##############################################

If ($UpdateVMs.Count -gt 0)
    {

    #Foreach updated VM, send a toast notification to the user

    #Set Toast Settings - Adjust to your own requirements - modification required
    $Script:ToastSettings = @{

        LogoImage = "$ToastMediafolder\ToastLogoImage.png"
        HeaderText = "VDI Manager Info" #Short Message Header
        AttributionText = "New VM Versions available" #Short Message small text

        TitleText = "New VM Versions available" #Long Message Header
        BodyText1 = "There is a new version available for the following VM(s)"#Long Message Text Line
        BodyText2 = $UpdateVMs | Out-String #Long Message Text Line
        ActionButtonContent = "Open VDI Manager" #Text for Action Button
    }
    # Adding and verifying Toast Application and Protocol Handler
    Add-NotificationApp -AppID $AppID -AppDisplayName $AppDisplayName -IconUri $IconUri | Out-Null
    Add-ToastLaunchVDIManagerProtocolHandler | Out-Null

        Invoke-ToastNotification -ToastSettings $ToastSettings -AppID $AppID -Scenario $Scenario
    }

############################################## Expired VMs - Toast Notification for non-GUI mode ##############################################

If ($ExpiredVMs.Count -gt 0)
    {
    #Foreach expired VM, send a toast notification to the user

    #Set Toast Settings - Adjust to your own requirements - modification required
    $Script:ToastSettings = @{

        LogoImage = "$ToastMediafolder\ToastLogoImage_Alert.png"
        HeaderText = "VDI Manager Info" #Short Message Header
        AttributionText = "Expired VMs found" #Short Message small text

        TitleText = "Expired VM found" #Long Message Header
        BodyText1 = "There are expired VMs that require attention" #Long Message Text Line
        BodyText2 = $ExpiredVMs | Out-String #Long Message Text Line
        ActionButtonContent = "Open VDI Manager" #Text for Action Button
    }
    # Adding and verifying Toast Application and Protocol Handler
    Add-NotificationApp -AppID $AppID -AppDisplayName $AppDisplayName -IconUri $IconUri | Out-Null
    Add-ToastLaunchVDIManagerProtocolHandler | Out-Null

        Invoke-ToastNotification -ToastSettings $ToastSettings -AppID $AppID -Scenario $Scenario

    }

############################################## Alert VMs - Toast Notification for non-GUI mode ##############################################

If ($AlertVMs.Count -gt 0)
    {
    #Foreach VM with an alert, send a toast notification to the user
    foreach ($AlertVM in $AlertVMs)
    {
    #Set Toast Settings - Adjust to your own requirements - modification required
    $Script:ToastSettings = @{

        LogoImage = "$ToastMediafolder\ToastLogoImage_Alert.png"
        HeaderText = "VDI Manager Info" #Short Message Header
        AttributionText = "Alerts for VMs found" #Short Message small text

        TitleText = "Alert message for VM found" #Long Message Header
        BodyText1 = "There is an alert for the $AlertVM VM:" #Long Message Text Line
        BodyText2 = $displayArray | Where-Object -property VMName -eq $AlertVM | Select-Object -ExpandProperty VersionDetails | Select-Object -ExpandProperty AlertMessage
        ActionButtonContent = "Open VDI Manager" #Text for Action Button
    }
    # Adding and verifying Toast Application and Protocol Handler
    Add-NotificationApp -AppID $AppID -AppDisplayName $AppDisplayName -IconUri $IconUri | Out-Null
    Add-ToastLaunchVDIManagerProtocolHandler | Out-Null

        Invoke-ToastNotification -ToastSettings $ToastSettings -AppID $AppID -Scenario $Scenario

    }
    }
