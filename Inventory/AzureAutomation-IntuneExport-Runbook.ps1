###########################################################################
## Azure automation runbook PowerShell script to export user data from   ##
## Microsoft Intune / Endpoint Manager and dump it to Azure CosmosDB     ##
## where it can be used as a datasource for Power BI.                    ##
###########################################################################

# Set some variables
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$CosmosDBEndPoint = "<INSERT Database URL here>"
$DatabaseId = "InventoryDatabase"
$MasterKey = "<INSERT Primary Database Key here>"
$Date = (Get-Date)

# add necessary assembly
#
Add-Type -AssemblyName System.Web

####################################################
# Connect to Azure
$resourceURL = "https://graph.microsoft.com/" 
$response = [System.Text.Encoding]::Default.GetString((Invoke-WebRequest -UseBasicParsing -Uri "$($env:IDENTITY_ENDPOINT)?resource=$resourceURL" -Method 'GET' -Headers @{'X-IDENTITY-HEADER' = "$env:IDENTITY_HEADER"; 'Metadata' = 'True'}).RawContentStream.ToArray()) | ConvertFrom-Json 
#$script:authToken = $response.access_token 

$script:authToken = @{
    'Content-Type'  = 'application/json'
    'Authorization' = "Bearer " + $response.access_token
}

######################################################

# generate authorization key
Function Generate-MasterKeyAuthorizationSignature
{
	[CmdletBinding()]
	Param
	(
		[Parameter(Mandatory=$true)][String]$verb,
		[Parameter(Mandatory=$true)][String]$resourceLink,
		[Parameter(Mandatory=$true)][String]$resourceType,
		[Parameter(Mandatory=$true)][String]$dateTime,
		[Parameter(Mandatory=$true)][String]$key,
		[Parameter(Mandatory=$true)][String]$keyType,
		[Parameter(Mandatory=$true)][String]$tokenVersion
	)

	$hmacSha256 = New-Object System.Security.Cryptography.HMACSHA256
	$hmacSha256.Key = [System.Convert]::FromBase64String($key)

	$payLoad = "$($verb.ToLowerInvariant())`n$($resourceType.ToLowerInvariant())`n$resourceLink`n$($dateTime.ToLowerInvariant())`n`n"
	$hashPayLoad = $hmacSha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($payLoad))
	$signature = [System.Convert]::ToBase64String($hashPayLoad);

	[System.Web.HttpUtility]::UrlEncode("type=$keyType&ver=$tokenVersion&sig=$signature")
}

# query
Function Post-CosmosDb
{
	[CmdletBinding()]
	Param
	(
		[Parameter(Mandatory=$true)][String]$EndPoint,
		[Parameter(Mandatory=$true)][String]$DataBaseId,
		[Parameter(Mandatory=$true)][String]$CollectionId,
		[Parameter(Mandatory=$true)][String]$MasterKey,
		[Parameter(Mandatory=$true)][String]$JSON
	)
try {
	$Verb = "POST"
	$ResourceType = "docs";
	$ResourceLink = "dbs/$DatabaseId/colls/$CollectionId"
    $partitionkey = "[""$(($JSON |ConvertFrom-Json).id)""]"

	$dateTime = [DateTime]::UtcNow.ToString("r")
	$authHeader = Generate-MasterKeyAuthorizationSignature -verb $Verb -resourceLink $ResourceLink -resourceType $ResourceType -key $MasterKey -keyType "master" -tokenVersion "1.0" -dateTime $dateTime
	$header = @{authorization=$authHeader;"x-ms-documentdb-partitionkey"=$partitionkey;"x-ms-version"="2018-12-31";"x-ms-date"=$dateTime}
	$contentType= "application/json"
	$queryUri = "$EndPoint$ResourceLink/docs"

	#Convert to UTF8 for special characters
	$defaultEncoding = [System.Text.Encoding]::GetEncoding('ISO-8859-1')
	$utf8Bytes = [System.Text.Encoding]::UTf8.GetBytes($JSON)
	$bodydecoded = $defaultEncoding.GetString($utf8bytes)

	Invoke-RestMethod -Method $Verb -ContentType $contentType -Uri $queryUri -Headers $header -Body $bodydecoded -ErrorAction SilentlyContinue
   } 
   catch 
   {
    return $_.Exception.Response.StatusCode.value__ 
   }
    
	
}

Function Replace-CosmosDb
{
	[CmdletBinding()]
	Param
	(
		[Parameter(Mandatory=$true)][String]$EndPoint,
		[Parameter(Mandatory=$true)][String]$DataBaseId,
		[Parameter(Mandatory=$true)][String]$CollectionId,
		[Parameter(Mandatory=$true)][String]$MasterKey,
		[Parameter(Mandatory=$true)][String]$JSON
	)
try {
	$Verb = "PUT"
	$ResourceType = "docs";
    $partitionkey = "[""$(($JSON |ConvertFrom-Json).id)""]"
    $DocID=($JSON |ConvertFrom-Json).id
	$ResourceLink = "dbs/$DatabaseId/colls/$CollectionId/docs/$DocID"


	$dateTime = [DateTime]::UtcNow.ToString("r")
	$authHeader = Generate-MasterKeyAuthorizationSignature -verb $Verb -resourceLink $ResourceLink -resourceType $ResourceType -key $MasterKey -keyType "master" -tokenVersion "1.0" -dateTime $dateTime
	$header = @{authorization=$authHeader;"x-ms-documentdb-partitionkey"=$partitionkey;"x-ms-version"="2018-12-31";"x-ms-date"=$dateTime}
	$contentType= "application/json"
	$queryUri = "$EndPoint$ResourceLink/"

	#Convert to UTF8 for special characters
	$defaultEncoding = [System.Text.Encoding]::GetEncoding('ISO-8859-1')
	$utf8Bytes = [System.Text.Encoding]::UTf8.GetBytes($JSON)
	$bodydecoded = $defaultEncoding.GetString($utf8bytes)

	Invoke-RestMethod -Method $Verb -ContentType $contentType -Uri $queryUri -Headers $header -Body $bodydecoded -ErrorAction SilentlyContinue
    } 
   catch 
   {
    return $_.Exception.Response.StatusCode.value__ 
   }
    
	
}

Function SendIntuneData-CosmosDb
{
	[CmdletBinding()]
	Param
	(
		[Parameter(Mandatory=$true)][String]$EndPoint,
		[Parameter(Mandatory=$true)][String]$DataBaseId,
		[Parameter(Mandatory=$true)][String]$CollectionId,
		[Parameter(Mandatory=$true)][String]$MasterKey,
		[Parameter(Mandatory=$true)][String]$JSON
	)

    
    $DeviceResult=Replace-CosmosDb -EndPoint $EndPoint -DataBaseId $DataBaseId -CollectionId $CollectionId -MasterKey $MasterKey -JSON $JSON
        If ($DeviceResult -eq "404")
            {
            $DeviceResult=Post-CosmosDb -EndPoint $EndPoint -DataBaseId $DataBaseId -CollectionId $CollectionId -MasterKey $MasterKey -JSON $JSON
            If ($DeviceResult -eq "429")
                {
                    sleep 1
                    $DeviceResult=Post-CosmosDb -EndPoint $EndPoint -DataBaseId $DataBaseId -CollectionId $CollectionId -MasterKey $MasterKey -JSON $JSON
                }
            }
        elseif ($DeviceResult -eq "429")
            {
                sleep 1
                $DeviceResult=Replace-CosmosDb -EndPoint $EndPoint -DataBaseId $DataBaseId -CollectionId $CollectionId -MasterKey $MasterKey -JSON $JSON
            }
}

####################################################PowerBI-Historical-Data####################################################


$Windows="https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=(((deviceType eq 'desktop') or (deviceType eq 'windowsRT') or (deviceType eq 'winEmbedded') or (deviceType eq 'surfaceHub') or (deviceType eq 'desktop') or (deviceType eq 'windowsRT') or (deviceType eq 'winEmbedded') or (deviceType eq 'surfaceHub') or (deviceType eq 'windowsPhone') or (deviceType eq 'holoLens')))&`$count=true"
$Apple="https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=(((deviceType eq 'iPad') or (deviceType eq 'iPhone') or (deviceType eq 'iPod')))&`$count=true"
$MacOS="https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=(deviceType eq 'macMDM')&`$count=true"
$Android="https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=((((deviceType eq 'android') or (deviceType eq 'androidForWork') or (deviceType eq 'androidnGMS')) or ((deviceType eq 'androidEnterprise') and ((deviceEnrollmentType eq 'androidEnterpriseDedicatedDevice') or (deviceEnrollmentType eq 'androidEnterpriseFullyManaged') or (deviceEnrollmentType eq 'androidEnterpriseCorporateWorkProfile')))))&`$count=true"
$timestamp = Get-Date -Format o
$Response = Invoke-WebRequest -Uri $Windows -Method Get -Headers $authToken -UseBasicParsing 
$JsonResponse = $Response.Content | ConvertFrom-Json
$WindowsCount = $JsonResponse."@odata.count"
Write-Output $WindowsCount

$Response = Invoke-WebRequest -Uri $Apple -Method Get -Headers $authToken -UseBasicParsing 
$JsonResponse = $Response.Content | ConvertFrom-Json
$AppleCount = $JsonResponse."@odata.count"
Write-Output $AppleCount

$Response = Invoke-WebRequest -Uri $MacOS -Method Get -Headers $authToken -UseBasicParsing 
$JsonResponse = $Response.Content | ConvertFrom-Json
$MacOSCount = $JsonResponse."@odata.count"
Write-Output $MacOSCount

$Response = Invoke-WebRequest -Uri $Android -Method Get -Headers $authToken -UseBasicParsing 
$JsonResponse = $Response.Content | ConvertFrom-Json
$AndroidCount = $JsonResponse."@odata.count"
Write-Output $AndroidCount

#$Line=$timestamp + ";" + $WindowsCount + ";" + $AppleCount +";" + $MacOSCount + ";" + $AndroidCount

# Create JSON to Upload to Log Analytics
		$Inventory = New-Object System.Object
        $Inventory | Add-Member -MemberType NoteProperty -Name "id" -Value "$timestamp" -Force
		$Inventory | Add-Member -MemberType NoteProperty -Name "WindowsCount" -Value "$WindowsCount" -Force
		$Inventory | Add-Member -MemberType NoteProperty -Name "AppleCount" -Value "$AppleCount" -Force
		$Inventory | Add-Member -MemberType NoteProperty -Name "MacOSCount" -Value "$MacOSCount" -Force
		$Inventory | Add-Member -MemberType NoteProperty -Name "AndroidCount" -Value "$AndroidCount" -Force
		$History = $Inventory | ConvertTo-Json


# Submit the data to the API endpoint
$DeviceResult=Post-CosmosDb -EndPoint $CosmosDBEndPoint -DataBaseId $DataBaseId -CollectionId "IntuneHistoricalDataContainer" -MasterKey $MasterKey -JSON $History

$WindowsCount =""
$AppleCount =""
$MacOSCount=""
$AndroidCount=""
$History=""

[system.gc]::Collect()

####################################################PowerBI-Devices####################################################

Write-Output "Export Devices"
$URI = "https://graph.microsoft.com/beta/DeviceManagement/managedDevices"
$Response = Invoke-WebRequest -Uri $URI -Method Get -Headers $authToken -UseBasicParsing 
$JsonResponse = $Response.Content | ConvertFrom-Json
$DeviceData = $JsonResponse.value

# Separate active devices
$Devices = $DeviceData | Where-Object {$_.id -ne $null} 

# Set property exclusion lists. These properties will not be included in the final datasets.
$DeviceExcludedProperties = @(
'activationLockBypassCode',
'chromeOSDeviceInfo',
'configurationManagerClientEnabledFeatures',
'configurationManagerClientHealthState',
'configurationManagerClientInformation',
'deviceActionResults',
'deviceHealthAttestationState',
'ethernetMacAddress',
'freeStorageSpaceInBytes',
'hardwareInformation',
'iccid',
'managedDeviceId',
'managedDeviceODataType',
'managedDeviceReferenceUrl',
'managementFeatures',
'physicalMemoryInBytes',
'processorArchitecture',
'remoteAssistanceSessionErrorDetails',
'remoteAssistanceSessionUrl',
'requireUserEnrollmentApproval',
'roleScopeTagIds',
'specificationVersion',
'totalStorageSpaceInBytes',
'udid',
'bootstrapTokenEscrowed',
'deviceFirmwareConfigurationInterfaceManaged'
)


# Exclude the unwanted properties and do some calculations
$Devices = $Devices | Select-Object -Property *,`
@{l="freeStorageSpaceInGB";e={[math]::Round(($_.freeStorageSpaceInBytes / 1GB),2)}},`
@{l="totalStorageSpaceInGB";e={[math]::Round(($_.totalStorageSpaceInBytes / 1GB),2)}}, `
@{l="physicalMemoryInGB";e={[math]::Round(($_.physicalMemoryInBytes / 1GB),2)}}, `
@{l="daysSinceLastSync";e={[math]::Round(((Get-Date) - ($_.lastSyncDateTime | Get-Date -ErrorAction SilentlyContinue)).TotalDays,0)}}, `
@{l="enabledCoMgmtWorkloads_inventory";e={$_.configurationManagerClientEnabledFeatures.inventory}}, `
@{l="enabledCoMgmtWorkloads_modernApps";e={$_.configurationManagerClientEnabledFeatures.modernApps}}, `
@{l="enabledCoMgmtWorkloads_resourceAccess";e={$_.configurationManagerClientEnabledFeatures.resourceAccess}}, `
@{l="enabledCoMgmtWorkloads_deviceConfiguration";e={$_.configurationManagerClientEnabledFeatures.deviceConfiguration}}, `
@{l="enabledCoMgmtWorkloads_compliancePolicy";e={$_.configurationManagerClientEnabledFeatures.compliancePolicy}}, `
@{l="enabledCoMgmtWorkloads_windowsUpdateForBusiness";e={$_.configurationManagerClientEnabledFeatures.windowsUpdateForBusiness}}, `
@{l="enabledCoMgmtWorkloads_endpointProtection";e={$_.configurationManagerClientEnabledFeatures.endpointProtection}}, `
@{l="enabledCoMgmtWorkloads_officeApps";e={$_.configurationManagerClientEnabledFeatures.officeApps}}, `
@{l="MEMCMClient_state";e={$_.configurationManagerClientHealthState.state}}, `
@{l="MEMCMClient_errorCode";e={$_.configurationManagerClientHealthState.errorCode}}, `
@{l="MEMCMClient_lastSyncDateTime";e={$_.configurationManagerClientHealthState.lastSyncDateTime}}, `
@{l="MEMCMClient_daysSinceLastSync";e={[math]::Round(((Get-Date) - ($_.configurationManagerClientHealthState.lastSyncDateTime | Get-Date -ErrorAction SilentlyContinue)).TotalDays,0)}} `
-ExcludeProperty $DeviceExcludedProperties

foreach ($device in $devices)

{

$Device = $Device | Convertto-Json

# Submit the data to the API endpoint

$DeviceResult=SendIntuneData-CosmosDb -EndPoint $CosmosDBEndPoint -DataBaseId $DataBaseId -CollectionId "IntuneDevicesContainer" -MasterKey $MasterKey -JSON $Device

}



If ($JsonResponse.'@odata.nextLink')
{
    do {
        $URI = $JsonResponse.'@odata.nextLink'
        $Response = Invoke-WebRequest -Uri $URI -Method Get -Headers $authToken -UseBasicParsing 
        $JsonResponse = $Response.Content | ConvertFrom-Json
        $DeviceData = $JsonResponse.value

# Separate active devices
$Devices = $DeviceData | Where-Object {$_.id -ne $null} 

# Set property exclusion lists. These properties will not be included in the final datasets.
$DeviceExcludedProperties = @(
'activationLockBypassCode',
'chromeOSDeviceInfo',
'configurationManagerClientEnabledFeatures',
'configurationManagerClientHealthState',
'configurationManagerClientInformation',
'deviceActionResults',
'deviceHealthAttestationState',
'ethernetMacAddress',
'freeStorageSpaceInBytes',
'hardwareInformation',
'iccid',
'managedDeviceId',
'managedDeviceODataType',
'managedDeviceReferenceUrl',
'managementFeatures',
'physicalMemoryInBytes',
'processorArchitecture',
'remoteAssistanceSessionErrorDetails',
'remoteAssistanceSessionUrl',
'requireUserEnrollmentApproval',
'roleScopeTagIds',
'specificationVersion',
'totalStorageSpaceInBytes',
'udid',
'bootstrapTokenEscrowed',
'deviceFirmwareConfigurationInterfaceManaged'
)


# Exclude the unwanted properties and do some calculations
$Devices = $Devices | Select-Object -Property *,`
@{l="freeStorageSpaceInGB";e={[math]::Round(($_.freeStorageSpaceInBytes / 1GB),2)}},`
@{l="totalStorageSpaceInGB";e={[math]::Round(($_.totalStorageSpaceInBytes / 1GB),2)}}, `
@{l="physicalMemoryInGB";e={[math]::Round(($_.physicalMemoryInBytes / 1GB),2)}}, `
@{l="daysSinceLastSync";e={[math]::Round(((Get-Date) - ($_.lastSyncDateTime | Get-Date -ErrorAction SilentlyContinue)).TotalDays,0)}}, `
@{l="enabledCoMgmtWorkloads_inventory";e={$_.configurationManagerClientEnabledFeatures.inventory}}, `
@{l="enabledCoMgmtWorkloads_modernApps";e={$_.configurationManagerClientEnabledFeatures.modernApps}}, `
@{l="enabledCoMgmtWorkloads_resourceAccess";e={$_.configurationManagerClientEnabledFeatures.resourceAccess}}, `
@{l="enabledCoMgmtWorkloads_deviceConfiguration";e={$_.configurationManagerClientEnabledFeatures.deviceConfiguration}}, `
@{l="enabledCoMgmtWorkloads_compliancePolicy";e={$_.configurationManagerClientEnabledFeatures.compliancePolicy}}, `
@{l="enabledCoMgmtWorkloads_windowsUpdateForBusiness";e={$_.configurationManagerClientEnabledFeatures.windowsUpdateForBusiness}}, `
@{l="enabledCoMgmtWorkloads_endpointProtection";e={$_.configurationManagerClientEnabledFeatures.endpointProtection}}, `
@{l="enabledCoMgmtWorkloads_officeApps";e={$_.configurationManagerClientEnabledFeatures.officeApps}}, `
@{l="MEMCMClient_state";e={$_.configurationManagerClientHealthState.state}}, `
@{l="MEMCMClient_errorCode";e={$_.configurationManagerClientHealthState.errorCode}}, `
@{l="MEMCMClient_lastSyncDateTime";e={$_.configurationManagerClientHealthState.lastSyncDateTime}}, `
@{l="MEMCMClient_daysSinceLastSync";e={[math]::Round(((Get-Date) - ($_.configurationManagerClientHealthState.lastSyncDateTime | Get-Date -ErrorAction SilentlyContinue)).TotalDays,0)}} `
-ExcludeProperty $DeviceExcludedProperties
foreach ($device in $devices)

{

$Device = $Device | Convertto-Json

# Submit the data to the API endpoint

$DeviceResult = SendIntuneData-CosmosDb -EndPoint $CosmosDBEndPoint -DataBaseId $DataBaseId -CollectionId "IntuneDevicesContainer" -MasterKey $MasterKey -JSON $Device

}


    } until ($null -eq $JsonResponse.'@odata.nextLink')
}



$Devices = ""
[system.gc]::Collect()




####################################################PowerBI-Users####################################################
Write-Output "Export Users"
$URI = "https://graph.microsoft.com/beta/users?`$select=id,userPrincipalName,country,city,companyName,department,DisplayName,onPremisesSamAccountNamejobTitle,mail,usageLocation&`$filter=accountEnabled eq true"
$Response = Invoke-WebRequest -Uri $URI -Method Get -Headers $authToken -UseBasicParsing 
$JsonResponse = $Response.Content | ConvertFrom-Json
$UserData = $JsonResponse.value
If ($JsonResponse.'@odata.nextLink')
{
    do {
        $URI = $JsonResponse.'@odata.nextLink'
        $Response = Invoke-WebRequest -Uri $URI -Method Get -Headers $authToken -UseBasicParsing 
        $JsonResponse = $Response.Content | ConvertFrom-Json
        $UserData += $JsonResponse.value
    } until ($null -eq $JsonResponse.'@odata.nextLink')
}


foreach ($Users in $UserData)
{
$users = $Users | Select-Object -Property id,userPrincipalName,country,city,companyName,department,DisplayName,onPremisesSamAccountNamejobTitle,mail,usageLocation | ConvertTo-Json
$DeviceResult=SendIntuneData-CosmosDb -EndPoint $CosmosDBEndPoint -DataBaseId $DataBaseId -CollectionId "IntuneUsersContainer" -MasterKey $MasterKey -JSON $Users
} 


$UserData =""

[system.gc]::Collect()


