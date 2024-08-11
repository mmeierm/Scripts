<#
Set Scope Tags to all Devices
#>

####################################################
#Define GroupPrefix
$ScopeTagGroupPrefix = "Intune - ScopeTags - Scope_"

####################################################
# Connect to Intune
$resourceURL = "https://graph.microsoft.com/" 
$response = [System.Text.Encoding]::Default.GetString((Invoke-WebRequest -UseBasicParsing -Uri "$($env:IDENTITY_ENDPOINT)?resource=$resourceURL" -Method 'GET' -Headers @{'X-IDENTITY-HEADER' = "$env:IDENTITY_HEADER"; 'Metadata' = 'True'}).RawContentStream.ToArray()) | ConvertFrom-Json 

$script:authToken = @{
    'Content-Type'  = 'application/json'
    'Authorization' = "Bearer " + $response.access_token
}


####################################################

Function Add-Member(){
    [cmdletbinding()]
    param
    (
       [Parameter(Mandatory=$true)] $ObjID,
       [Parameter(Mandatory=$true)] $GroupID
    )

        $DevUri = "https://graph.microsoft.com/beta/devices/" + $Objid
        $id = "@odata.id"
        $JSON = @{ $id="$DevUri" } | ConvertTo-Json -Compress
        $uri="https://graph.microsoft.com/beta/groups/$GroupID/members/`$ref"
		Invoke-RestMethod -Uri $uri -Headers $authToken -Method Post -Body $JSON -ContentType "application/json"	
}


Function Get-Members(){
    [cmdletbinding()]
    param
    (
       [Parameter(Mandatory=$true)] $GroupID
    )

        $uri="https://graph.microsoft.com/beta/groups/$GroupID/members?`$select=id,deviceId"
		$Response=Invoke-RestMethod -Uri $uri -Headers $authToken -Method GET -UseBasicParsing
        $Groupmembers = $Response.value
        If ($Response.'@odata.nextLink')
        {
            do {
                $URI = $Response.'@odata.nextLink'
                $Response = Invoke-RestMethod -Uri $URI -Method Get -Headers $authToken -UseBasicParsing 
                $Groupmembers += $Response.value
            } until ($null -eq $Response.'@odata.nextLink')
        }
        return $Groupmembers
}

Function Remove-Member(){
    [cmdletbinding()]
    param
    (
       [Parameter(Mandatory=$true)] $ObjID,
       [Parameter(Mandatory=$true)] $GroupID
    )

        $uri="https://graph.microsoft.com/beta/groups/$GroupID/members/$Objid/`$ref"
		Invoke-RestMethod -Uri $uri -Headers $authToken -Method Delete
}

############################################################################################################################################################
Write-Output "Search for existing ScopeTag Groups based of prefix"

$uri="https://graph.microsoft.com/beta/groups/?`$filter=startswith(displayname, '$ScopeTagGroupPrefix')&`$select=id,displayname"
$Groups=(Invoke-RestMethod -Uri $uri -Headers $authToken -Method GET -ContentType "application/json").value
$ScopeTagGroups = @{}
$OptimizeGroups = @{} 
foreach ($Group in $Groups)
{
    $OptimizeGroups.Add($Group.displayName,$Group.id)
    $Members = Get-Members -GroupID $Group.id
    foreach ($Member in $Members)
    {
        $ScopeTagGroups.Add($member.deviceid, "$($Group.displayname);$($Group.id)")
    }

}

############################################################################################################################################################

Write-Output "Export Entra Devices"
# prepare Hashtable that will keep DeviceID as a key
$OptimizeDevices = @{}
$URI = "https://graph.microsoft.com/beta/devices?`$filter=accountEnabled eq true&`$select=id,deviceId,mdmAppId"
$Response = Invoke-WebRequest -Uri $URI -Method Get -Headers $authToken -UseBasicParsing 
$JsonResponse = $Response.Content | ConvertFrom-Json
$EntraDeviceData = $JsonResponse.value
If ($JsonResponse.'@odata.nextLink')
{
    do {
        $URI = $JsonResponse.'@odata.nextLink'
        $Response = Invoke-WebRequest -Uri $URI -Method Get -Headers $authToken -UseBasicParsing 
        $JsonResponse = $Response.Content | ConvertFrom-Json
        $EntraDeviceData += $JsonResponse.value
    } until ($null -eq $JsonResponse.'@odata.nextLink')
}


foreach ($EntraDevice in $EntraDeviceData)
{
If($EntraDevice.mdmAppId -ne 'null')
{
    $EntraDevice = $EntraDevice | Select-Object -Property id,deviceId
    $OptimizeDevices.Add($Entradevice.deviceId,$EntraDevice)
}
} 

$EntraDeviceData =""
[system.gc]::Collect()


############################################################################################################################################################
#Entra Users
Write-Output "Export Entra Users"
# prepare Hashtable that will keep DeviceID as a key
$OptimizeUsers = @{}

$uri = "https://graph.microsoft.com/beta/users/?`$filter=userType+eq+%27Member%27&`$select=id%2cuserPrincipalName%2ccompanyName%2cusageLocation"
$UsersResponse = (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get)
$Users = $UsersResponse.value

$UsersNextLink = $UsersResponse."@odata.nextLink"

while ($null -ne $UsersNextLink){

    $UsersResponse = (Invoke-RestMethod -Uri $UsersNextLink -Headers $authToken -Method Get)
    $UsersNextLink = $UsersResponse."@odata.nextLink"
    $Users += $UsersResponse.value
}

foreach ($_ in $Users) {
    $OptimizeUsers.Add($_.id,$_)
}

$Users =""
[system.gc]::Collect()

############################################################################################################################################################

Write-Output "Export Intune Devices"
$URI = "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$select=id,azureADDeviceId,userId"
$Response = Invoke-WebRequest -Uri $URI -Method Get -Headers $authToken -UseBasicParsing 
$JsonResponse = $Response.Content | ConvertFrom-Json
$IntuneData = $JsonResponse.value
If ($JsonResponse.'@odata.nextLink')
{
    do {
        $URI = $JsonResponse.'@odata.nextLink'
        $Response = Invoke-WebRequest -Uri $URI -Method Get -Headers $authToken -UseBasicParsing 
        $JsonResponse = $Response.Content | ConvertFrom-Json
        $IntuneData += $JsonResponse.value
    } until ($null -eq $JsonResponse.'@odata.nextLink')
}

####################################################

foreach ($IntuneDevice in $IntuneData)
{
    If ($IntuneDevice.userId -and $null -ne $IntuneDevice.azureADDeviceID -and $IntuneDevice.azureADDeviceID -ne "" -and $IntuneDevice.azureADDeviceID -ne "00000000-0000-0000-0000-000000000000" )
    {
        #Define needed ScopeTag
        try {
            $useagelocation = ($OptimizeUsers[$IntuneDevice.userid]).usageLocation
            If($useagelocation)
            {
                $neededScopeTagGroup = $ScopeTagGroupPrefix + $useagelocation
            }
            else 
            {
                $neededScopeTagGroup = $ScopeTagGroupPrefix + "OTHER"
            }
            
        }
        catch {
            $neededScopeTagGroup = $ScopeTagGroupPrefix + "OTHER"
        }
    }
    else 
    {
        $neededScopeTagGroup = $ScopeTagGroupPrefix + "OTHER"
    }


    #Check if device is already in a ScopeTag Group
    try {
        $currentScopeTag = $ScopeTagGroups[$IntuneDevice.azureADDeviceId]
    }
    catch {
        $currentScopeTag = $null
    }

    #Check if current Group (if existing) matches desired Group
    If ($currentScopeTag)  #If current scopeTag existing and is not matching, removing device from group, prior to assinging it to the new group
    {
        $currentScopeTagName=$currentScopeTag.Split(';')[0]
        If ($neededScopeTagGroup -ne $currentScopeTagName)
        {
            #Search for Entra Object
            try {
                $Entraobject = $OptimizeDevices[$IntuneDevice.azureADDeviceID]
            }
            catch {
                $Entraobject = $null
            }
            #If Entra Object found, start assinging Group
            If($Entraobject)
            {
                    $Groupid=$currentScopeTag.Split(';')[1]
                    $null=Remove-Member -GroupID $Groupid -ObjID $Entraobject.id
                    $Groupid = $OptimizeGroups[$neededScopeTagGroup]
                    If($Groupid)
                    {
                    $null=Add-Member -GroupID $Groupid -ObjID $Entraobject.id
                    }
                    else 
                    {
                        Write-Output "No GroupID found for $neededScopeTagGroup"
                    }
            }

        }
    }

    else 
    {
        #Search for Entra Object
        try {
            $Entraobject = $OptimizeDevices[$IntuneDevice.azureADDeviceID]
        }
        catch {
            $Entraobject = $null
        }
        #If Entra Object found, start assinging Group
        If($Entraobject)
        {
            #Get GroupID
            $Groupid = $OptimizeGroups[$neededScopeTagGroup]
            If($Groupid)
            {
                $null=Add-Member -GroupID $Groupid -ObjID $Entraobject.id
            }
            else 
            {
                Write-Output "No GroupID found for $neededScopeTagGroup"
            }
            
        }
    }
    
}
