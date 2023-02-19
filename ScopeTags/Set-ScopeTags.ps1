<#
Set Scope Tags to all Devices
Parameter Mode: 
Full => Loop through all devices
Inc => Loop through devices with Enrollment Date <= 2days
Webhook => Apply only selected device from Webhook Data (Via SN)
#>

####################################################

param
(
[parameter(Mandatory=$true)]
$Mode,
[Parameter (Mandatory=$false)]
[object] $WebhookData
)

####################################################
function Connect-Intune {
# Connect to Intune
$resourceURL = "https://graph.microsoft.com/" 
$response = [System.Text.Encoding]::Default.GetString((Invoke-WebRequest -UseBasicParsing -Uri "$($env:IDENTITY_ENDPOINT)?resource=$resourceURL" -Method 'GET' -Headers @{'X-IDENTITY-HEADER' = "$env:IDENTITY_HEADER"; 'Metadata' = 'True'}).RawContentStream.ToArray()) | ConvertFrom-Json 
#$script:authToken = $response.access_token 

$script:authToken = @{
    'Content-Type'  = 'application/json'
    'Authorization' = "Bearer " + $response.access_token
}
}

####################################################
Function Get-ManagedDevicesbySN() {
    [cmdletbinding()]
    param
    (
        $WebhookSN
    )
   
    $graphApiVersion = "beta"
    $Resource = "deviceManagement/managedDevices?filter=(serialNumber eq '$WebhookSN')"
    
    try {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
            $DevicesResponse = (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get)
            $Devices = $DevicesResponse.value
            $DevicesNextLink = $DevicesResponse."@odata.nextLink"
            while ($DevicesNextLink -ne $null) {
                $DevicesResponse = (Invoke-RestMethod -Uri $DevicesNextLink -Headers $authToken -Method Get)
                $DevicesNextLink = $DevicesResponse."@odata.nextLink"
                $Devices += $DevicesResponse.value
            }
            return $Devices
        }
    catch {
        Write-output "Error : $($error[0].exception.message)"
        exit
    }
}
Function Get-ManagedDevicesbyEnrollmentDate() {

    $yesterday = (Get-Date -Date (Get-date).AddDays(-2) -Format yyyy-MM-dd) + "T00:00:00.000Z"
    $graphApiVersion = "beta"
    $Resource = "deviceManagement/managedDevices?filter=(enrolleddatetime gt $yesterday)"
    
    try {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
            $DevicesResponse = (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get)
            $Devices = $DevicesResponse.value
            $DevicesNextLink = $DevicesResponse."@odata.nextLink"
            while ($DevicesNextLink -ne $null) {
                $DevicesResponse = (Invoke-RestMethod -Uri $DevicesNextLink -Headers $authToken -Method Get)
                $DevicesNextLink = $DevicesResponse."@odata.nextLink"
                $Devices += $DevicesResponse.value
            }
            return $Devices
        }
    catch {
        Write-output "Error : $($error[0].exception.message)"
        exit
    }
}


Function Get-ManagedDevices() {
    [cmdletbinding()]
    param
    (
        $DeviceName,
        $id
    )
    $graphApiVersion = "beta"
    $Resource = "deviceManagement/managedDevices"
    try {

            $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
            $DevicesResponse = (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get)
            $Devices = $DevicesResponse.value
            $DevicesNextLink = $DevicesResponse."@odata.nextLink"
            while ($null -ne $DevicesNextLink) {
                $DevicesResponse = (Invoke-RestMethod -Uri $DevicesNextLink -Headers $authToken -Method Get)
                $DevicesNextLink = $DevicesResponse."@odata.nextLink"
                $Devices += $DevicesResponse.value
            }
            return $Devices
    }
    catch {
        Write-output "Error : $($error[0].exception.message)"
        exit
    }
}
function Get-RoleScopeTags() {
    $graphApiVersion = "beta"
    $uri = "https://graph.microsoft.com/$graphApiVersion/deviceManagement/roleScopeTags"
    $resultResponse = (Invoke-RestMethod -Uri $uri -Headers $authToken -Method GET)
    $result = $resultResponse.Value
    $ResultNextLink = $resultResponse."@odata.nextLink"
    while ($null -ne $ResultNextLink) {
        $resultResponse = (Invoke-RestMethod -Uri $ResultNextLink -Headers $authToken -Method Get)
        $ResultNextLink = $resultResponse."@odata.nextLink"
        $result += $resultResponse.value
    }
    $resulthash = @{}
    foreach ($tag in $result) {
        $resulthash.Add($tag.displayName, $tag.id)
    }
    return $resulthash
}
function Add-RoleScopeTags($ScopeTags) {
    $graphApiVersion = "beta"
    $uri = "https://graph.microsoft.com/$graphApiVersion/deviceManagement/roleScopeTags"
    $body = @"
{
  "`@odata.type": "#microsoft.graph.roleScopeTag",
  "displayName": "$ScopeTags"
}
"@
    $res = Invoke-RestMethod -uri $uri -Headers $authToken -Method POST -Body $body -ContentType "application/json"
    $script:rolescopetags.Add($res.displayName, $res.id)
    Write-Output "Successfully Added RoleScopeTags"
}
function Get-DeviceRoleScopeIds($id, $ScopeTag) {
    $uri = "https://graph.microsoft.com/$graphApiVersion/deviceManagement/managedDevices('$id')/?$select=roleScopeTagId"
    $result = (Invoke-RestMethod -Uri $uri -Headers $authToken -Method GET).roleScopeTagIds
    return $result
}
function Update-RoleScopeTags() {
    [cmdletbinding()]
    param
    (
        $ScopeTags
    )
    try {
        if ($ScopeTags -eq "" -or $null -eq $ScopeTags) {
            break
        }
        if (!($script:rolescopetags.ContainsKey($ScopeTags))) {
            Add-RoleScopeTags -headers $authToken -ScopeTags $ScopeTags
        }
    }
    catch {
        Write-output "Error: $($error.exception.message)"
    }
}
function Get-GraphBetaDataBatchRequest {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $bodyJson,
        # Determinds how many retries after consecutive throtteling errors shall be made
        [Parameter(Mandatory = $false)]
        [string]
        $RetryCount = 5
    )

    $url = "https://graph.microsoft.com/beta/`$batch"
    $resultsRaw = Invoke-WebRequest -Method Post -Uri $url -ContentType "application/json" -Headers $authToken -Body $bodyJson -UseBasicParsing
    if ($resultsRaw.StatusCode -eq 200) {
        return ($resultsRaw.Content | ConvertFrom-Json).responses
    }
    # Checks if graph request gets throttled - see: https://docs.microsoft.com/de-de/graph/throttling
    elseif ($resultRaw.StatusCode -eq 429 -and $RetryCount -gt 0) {
        Start-Sleep -Seconds ($resultRaw.Headers."Retry-After" + 5)
        return Get-GraphBetaDataBatchRequest -bodyJson $bodyJson -RetryCount ($RetryCount - 1)
    }
    else {
        throw "GraphData couldn't be acquired"
    }
}
function Get-CurrentScopeTag {
    param (
        $URLAPI,
        $ObjID,
        $RetryCount = 5
    )
    Connect-Intune
    $url = "https://graph.microsoft.com/beta/$URLAPI/$ObjID"
    $resultsRaw = Invoke-WebRequest -Method Get -Uri $url -Headers $authtoken -UseBasicParsing 
    if ($resultsRaw.StatusCode -eq 200) {
        return ($resultsRaw.Content | ConvertFrom-Json)
    }
    # Checks if graph request gets throttled - see: https://docs.microsoft.com/de-de/graph/throttling
    elseif ($resultRaw.StatusCode -eq 429 -and $RetryCount -gt 0) {
        Start-Sleep -Seconds ($resultRaw.Headers."Retry-After" + 5)
        return Get-GraphBetaDataBatchRequest -bodyJson $bodyJson -RetryCount ($RetryCount - 1)
    }
    else {
        throw "GraphData couldn't be acquired"
    }
    
}
function Get-UserDepartments {
    param(
        [Parameter(Mandatory = $true)]
        [Object[]]
        $devices
    )
    $users = $devices | Select-Object -ExpandProperty UserPrincipalName -Unique | Where-Object { -not [String]::IsNullOrWhiteSpace($_) }
    $i = 0
    $counter = 0
    $requests = @()
    foreach ($upn in $users) {
        $requests += [PSCustomObject]@{
            id     = "$upn"
            method = "GET"
            url    = "/users/$upn/?`$select=usageLocation,userPrincipalName"
        }
        $counter++
        if ($counter -ge 20 -or $i -ge ($users.Count - 1)) {
            $counter = 0
            $body = [PSCustomObject]@{
                requests = $requests
            }
            $batchResults = Get-GraphBetaDataBatchRequest -bodyJson ($body | ConvertTo-Json) -ErrorAction Stop
            foreach ($batchResult in $batchResults) {

					$Scopefull= "Scope_" + $batchResult.body.usageLocation
					$Script:userDepartHash.Add($batchResult.body.userPrincipalName, $Scopefull)
				
            }
            $requests = @()
        }
        $i++
    }
    foreach ($device in $devices) {
        if ($null -ne $Script:userDepartHash[$device.userPrincipalName]) 
        {
            $departmentcode = $Script:userDepartHash[$device.userPrincipalName]
            $Script:devicedeparthash.Add($device.Id, $departmentcode)
        }
        elseif ($device.userPrincipalName -notcontains "@")
        {
            $departmentcode = "Scope_OTHER"
            $Script:devicedeparthash.Add($device.Id, $departmentcode)
        }
        else
        {
            $departmentcode = "Scope_OTHER"
            $Script:devicedeparthash.Add($device.Id, $departmentcode)
        }
    }
}
function Update-ManagedDeviceRoleScopeTags {
    $counterDeviceDepartHash = 1
    $i = 0
    $requests = @()
    $counter = 0
    foreach ($key in $Script:devicedeparthash.Keys) {
        Update-RoleScopeTags -ScopeTags $Script:devicedeparthash[$key]
        $tagid = $Script:rolescopetags[$Script:devicedeparthash[$key]]
        $taglist = @()
        if ($null -ne $tagid) {
            $taglist += $tagid
        }
        $taglist += "0"
        $object = [PSCustomObject]@{
            roleScopeTagIds = $taglist
        }
        $requests += [PSCustomObject]@{
            id      = "$key"
            method  = "PATCH"
            url     = "/deviceManagement/managedDevices/$key"
            body    = $object
            headers = [PSCustomObject]@{
                "Content-Type" = "application/json"
            }
        }
        Write-Output "Iteration $counterDeviceDepartHash of $($Script:devicedeparthash.count)"
        $counterDeviceDepartHash++
        $counter++
        if ($counter -ge 20 -or $i -ge ($Script:devicedeparthash.Count - 1)) {
            $counter = 0
            $body = [PSCustomObject]@{
                requests = $requests
            }
            $results = Get-GraphBetaDataBatchRequest -bodyJson ($body | ConvertTo-Json -Depth 4) -ErrorAction Stop
            $requests = @()
        }
        $i++
    }
}



############################################################################################################################################################
$Script:devicedeparthash = @{}
$Script:userDepartHash = @{}

Connect-Intune

############################################################################################################################################################



If($Mode -eq "Full")
{
    $result = Get-ManagedDevices
}
elseif($Mode -eq "Webhook")
{
    If($WebhookData)
    {
    $WebhookData=(ConvertFrom-Json -InputObject $WebhookData)
    
    $Client=(ConvertFrom-Json -InputObject $WebhookData.RequestBody)
    $WebhookName=$client.Name
    $WebhookSN=$Client.SN
    Write-Output "Updating ScopeTag of Client $WebhookName with SerialNumer $WebhookSN as requested via Webhook"
    $result= Get-ManagedDevicesbySN -WebhookSN $WebhookSN
    }
    else {
        Write-Output "Invalid Data from Webhook"
        exit 1
        }
}
else
{
    $result = Get-ManagedDevicesbyEnrollmentDate
}

$Script:rolescopetags = Get-RoleScopeTags
Get-UserDepartments -Devices $result
Update-ManagedDeviceRoleScopeTags
