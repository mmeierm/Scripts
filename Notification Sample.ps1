
#region Initialisations
# Set Error Action to Silently Continue
$Script:ErrorActionPreference = "SilentlyContinue"
$Script:ExitCode = 0
#endregion Initialisations
#region Decalarations 
# Create and define Eventlog for logging - edit with caution 
$Script:EventLogName = 'MikeMDM'
$Script:EventLogSource = 'MikeMDMNotifications'
New-EventLog -LogName $EventLogName -Source $EventLogSource -ErrorAction SilentlyContinue
# Set Toast Notification App Parameters - do not edit 
$Script:AppID = "MikeMDM.SystemToast.UpdateNotification"
$Script:AppDisplayName = "MikeMDM"
$Script:ToastMediafolder = "$env:programdata\MikeMDM\ToastNotification"
$IconPath= Join-path $ToastMediafolder "Icon.png"

#Verify Toast Media folder exists
if (-not (Test-Path $ToastMediafolder)){
    New-Item -Path $ToastMediafolder -ItemType Directory | Out-Null
}
Invoke-WebRequest -uri "<#INSERT URL TO INFO LOGO HERE#>" -OutFile $IconPath
$Script:IconUri = $IconPath


#Set Toast Settings - Adjust to your own requirements - modification required
$Script:ToastSettings = @{

    LogoImageUri = "<#INSERT URL TO COMPANY LOGO HERE#>"
    HeroImageUri = "<#INSERT URL TO HERO IMAGE HERE#>"
    LogoImage = "$ToastMediafolder\ToastLogoImage.png"
    HeroImage = "$ToastMediafolder\ToastHeroImage.png"
    AttributionText = "Wichtige Infos zu Windows 11" #Short Message small text
    HeaderText = "Windows 11 Upgrade" #Short Message Header
    TitleText = "Schon mitbekommen?" #Long Message Header
    BodyText1 = "Der Windows 11 Rollout in der IT startet im Februar"#Long Message Text Line
    BodyText2 = "Informieren Sie sich vor dem Update, über die Neuerungen in der neuen Windows 11 FAQ im Intranet"#Long Message Text Line
    ActionButtonContent = "Windows 11 FAQ"
}
$Script:Scenario = 'reminder' # <!-- Possible values are: reminder | short | long | alarm
# Registry path for status messages - do not edit
$Script:RegPath = 'HKLM:\SOFTWARE\MikeMDM\Notifications'

#EndRegion Declarations 

#Region Functions

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
function Add-ToastRebootProtocolHandler{
    <#
    .SYNOPSIS
    Function to add the reboot protocol handler for your toast notifications

    .DESCRIPTION
    This function must be run as system and registers the protocal handler for toast reboot. 
    #>   
    New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT -ErrorAction SilentlyContinue | out-null
    $ProtocolHandler = Get-Item 'HKCR:\MikeMDMToastReboot' -ErrorAction SilentlyContinue

        #create handler for reboot
        Remove-Item 'HKCR:\MikeMDMToastReboot' -Force -recurse

        New-Item 'HKCR:\MikeMDMToastReboot' -Force
        Set-Itemproperty 'HKCR:\MikeMDMToastReboot' -Name '(DEFAULT)' -Value 'url:MikeMDMToastReboot' -Force
        Set-Itemproperty 'HKCR:\MikeMDMToastReboot' -Name 'URL Protocol' -Value '' -Force
        New-Itemproperty -path 'HKCR:\MikeMDMToastReboot' -PropertyType DWORD -Name 'EditFlags' -Value 2162688
        New-Item 'HKCR:\MikeMDMToastReboot\Shell\Open\command' -Force
        Set-Itemproperty 'HKCR:\MikeMDMToastReboot\Shell\Open\command' -Name '(DEFAULT)' -Value '"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" "https://mikemdm.de"' -Force
    
    Remove-PSDrive -Name HKCR -Force -ErrorAction SilentlyContinue
}#endfunction
function Test-UserSession {
    #Check if a user is currently logged on before doing user action
    [String]$CurrentlyLoggedOnUser = (Get-WmiObject -Class Win32_ComputerSystem |  Where-Object {$_.Username} | Select-Object UserName).UserName
    if ($CurrentlyLoggedOnUser){
        $SAMName = [String]$CurrentlyLoggedOnUser.Split("\")[1]
        #$UserPath = (Get-ChildItem  -Path HKLM:\SOFTWARE\Microsoft\IdentityStore\LogonCache\ -Recurse -ErrorAction SilentlyContinue | ForEach-Object { if((Get-ItemProperty -Path $_.PsPath) -match $SAMName) {$_.PsPath} } ) | Where-Object {$PSItem -Match 'S-\d-\d{2}-\d-\d{10}-\d{10}-\d{10}-\d{10}'}
        #$FullName = (Get-ItemProperty -Path $UserPath | Select-Object DisplayName).DisplayName
        $ReturnObject = $SAMName 
    }else {
        $ReturnObject = $false
    }
    Return $ReturnObject
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
#Fetching images from uri
Invoke-WebRequest -Uri `"$($ToastSettings.LogoImageUri)`" -OutFile $($ToastSettings.LogoImage)
Invoke-WebRequest -Uri `"$($ToastSettings.HeroImageUri)`" -OutFile $($ToastSettings.HeroImage)
[xml]`$Toast = @`"
<toast scenario=`"$Scenario`">
    <visual>
    <binding template=`"ToastGeneric`">
        <image placement=`"hero`" src=`"$($ToastSettings.HeroImage)`"/>
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
	<action activationType=`"protocol`" arguments=`"MikeMDMToastReboot:`" content=`"$($ToastSettings.ActionButtonContent)`"/>
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
}#endfunction
#Endregion Functions

#Region Script


# Adding and verifying Toast Application and Protocol Handler
Add-NotificationApp -AppID $AppID -AppDisplayName $AppDisplayName -IconUri $IconUri | Out-Null
Add-ToastRebootProtocolHandler | Out-Null

            Invoke-ToastNotification -ToastSettings $ToastSettings -AppID $AppID -Scenario $Scenario
