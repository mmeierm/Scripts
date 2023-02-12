param
(
[Parameter (Mandatory=$false)]
[object] $WebhookData
)

# Connect to Intune
$resourceURL = "https://graph.microsoft.com/" 
$response = [System.Text.Encoding]::Default.GetString((Invoke-WebRequest -UseBasicParsing -Uri "$($env:IDENTITY_ENDPOINT)?resource=$resourceURL" -Method 'GET' -Headers @{'X-IDENTITY-HEADER' = "$env:IDENTITY_HEADER"; 'Metadata' = 'True'}).RawContentStream.ToArray()) | ConvertFrom-Json 
#$script:authToken = $response.access_token 

$script:authToken = @{
    'Content-Type'  = 'application/json'
    'Authorization' = "Bearer " + $response.access_token
}

####################################################Functions for Import####################################################

Function Get-AutoPilotDevice(){
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$false)] $id
    )
    
        # Defining Variables
        
        if ($id) {
            $uri = "https://graph.microsoft.com/v1.0/deviceManagement/windowsAutopilotDeviceIdentities/$id"
        }
        else {
            $uri = "https://graph.microsoft.com/v1.0/deviceManagement/windowsAutopilotDeviceIdentities/$Resource"
        }
        try {
            $response = Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get
            if ($id) {
                $response
            }
            else {
                $response.Value
            }
        }
        catch {
    
            $ex = $_.Exception
            $errorResponse = $ex.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($errorResponse)
            $reader.BaseStream.Position = 0
            $reader.DiscardBufferedData()
            $responseBody = $reader.ReadToEnd();
    
            Write-Output "Response content:`n$responseBody"
            Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
    
            break
        }
    
    }
    

Function Get-AutoPilotImportedDevice(){
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$false)] $id
)

      if ($id) {
        $uri = "https://graph.microsoft.com/v1.0/deviceManagement/importedWindowsAutopilotDeviceIdentities/$id"
    }
    else {
        $uri = "https://graph.microsoft.com/v1.0/deviceManagement/importedWindowsAutopilotDeviceIdentities/$Resource"
    }
   
        $response = Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get
        if ($id) {
            $response
        }
        else {
            $response.Value
        }
}

Function Add-AutoPilotImportedDevice(){
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true)] $serialNumber,
        [Parameter(Mandatory=$true)] $hardwareIdentifier,
        [Parameter(Mandatory=$false)] $orderIdentifier
    )
    
        # Defining Variables
    
        $uri = "https://graph.microsoft.com/v1.0/deviceManagement/importedWindowsAutopilotDeviceIdentities/$Resource"
        $json = @"
{
    "@odata.type": "#microsoft.graph.importedWindowsAutopilotDeviceIdentity",
    "orderIdentifier": "$orderIdentifier",
    "serialNumber": "$serialNumber",
    "productKey": "",
    "hardwareIdentifier": "$hardwareIdentifier",
    "state": {
        "@odata.type": "microsoft.graph.importedWindowsAutopilotDeviceIdentityState",
        "deviceImportStatus": "pending",
        "deviceRegistrationId": "",
        "deviceErrorCode": 0,
        "deviceErrorName": ""
        }
}
"@

        try {
            $Response=(Invoke-RestMethod -Uri $uri -Headers $authToken -Method Post -Body $json -ContentType "application/json").ID
            return $Response
        }
        catch {
    
            $ex = $_.Exception
            $errorResponse = $ex.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($errorResponse)
            $reader.BaseStream.Position = 0
            $reader.DiscardBufferedData()
            $responseBody = $reader.ReadToEnd();
    
            Write-Output "Response content:`n$responseBody"
            Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
    
            break
        }
    
    }

    
Function Remove-AutoPilotImportedDevice(){
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true)] $id
    )

        $uri = "https://graph.microsoft.com/v1.0/deviceManagement/importedWindowsAutopilotDeviceIdentities/$id"

        try {
            Invoke-RestMethod -Uri $uri -Headers $authToken -Method Delete | Out-Null
        }
        catch {
    
            $ex = $_.Exception
            $errorResponse = $ex.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($errorResponse)
            $reader.BaseStream.Position = 0
            $reader.DiscardBufferedData()
            $responseBody = $reader.ReadToEnd();
    
            Write-Output "Response content:`n$responseBody"
            Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
    
            break
        }
        
}

####################################################Import Main Function####################################################

Function Import-AutoPilotCSV(){
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true)] $Serial,
        [Parameter(Mandatory=$true)] $GroupTag,
        [Parameter(Mandatory=$true)] $hash
    )


            $ImportID=Add-AutoPilotImportedDevice -serialNumber $serial -hardwareIdentifier $hash -orderIdentifier $GroupTag
        
        # While we could keep a list of all the IDs that we added and then check each one, it is 
        # easier to just loop through all of them
        $processingCount = 1
        while ($processingCount -gt 0)
        {
			Start-Sleep 60
            $deviceStatuses = Get-AutoPilotImportedDevice -id $ImportID
            $deviceCount = "1"

            # Check to see if any devices are still processing (enhanced by check for pending)
            $processingCount = 0
            foreach ($device in $deviceStatuses){
                if ($($device.state.deviceImportStatus).ToLower() -eq "unknown" -or $($device.state.deviceImportStatus).ToLower() -eq "pending") {
                    $processingCount = $processingCount + 1
                }
            }
            Write-Output "Waiting for $processingCount of $deviceCount"

            # Still processing?  Sleep before trying again.
            if ($processingCount -gt 0){
                Start-Sleep 15
            }
        }

        # Generate some statistics for reporting...
        $global:successCount = 0
        $global:errorCount = 0
        $global:softErrorCount = 0
        $global:errorList = @{}
        $global:successList = @{}

        ForEach ($deviceStatus in $deviceStatuses) {
            if ($($deviceStatus.state.deviceImportStatus).ToLower() -eq 'success' -or $($deviceStatus.state.deviceImportStatus).ToLower() -eq 'complete') {
                $global:successCount += 1
                $global:successList.Add($deviceStatus.serialNumber, $deviceStatus.state)
            } elseif ($($deviceStatus.state.deviceImportStatus).ToLower() -eq 'error') {
                $global:errorCount += 1
                # ZtdDeviceAlreadyAssigned will be counted as soft error, free to delete
                if ($($deviceStatus.state.deviceErrorCode) -eq 806) {
                    $global:softErrorCount += 1
                }
                $global:errorList.Add($deviceStatus.serialNumber, $deviceStatus.state)
            }
        }

        # Display the statuses
        $deviceStatuses | ForEach-Object {
            Write-Output "Serial number $($_.serialNumber): $($_.state.deviceImportStatus), $($_.state.deviceErrorCode), $($_.state.deviceErrorName)"

            $ImportedAutopilotDevice = New-Object System.Object
            $ImportedAutopilotDevice | Add-Member -MemberType NoteProperty -Name "SerialNumber" -Value $($_.serialNumber) -Force   
            $ImportedAutopilotDevice | Add-Member -MemberType NoteProperty -Name "Status" -Value $($_.state.deviceImportStatus) -Force   
            $ImportedAutopilotDevice | Add-Member -MemberType NoteProperty -Name "ErrorCode" -Value $($_.state.deviceErrorCode) -Force      
            $ImportedAutopilotDevice | Add-Member -MemberType NoteProperty -Name "ErrorName" -Value $($_.state.deviceErrorName) -Force  
            $AutopilotJson = $ImportedAutopilotDevice | ConvertTo-Json
            $ResponseLAUpload = Send-LogAnalyticsData -customerId $WorkspaceID -sharedKey $SharedKey -body ([System.Text.Encoding]::UTF8.GetBytes($AutopilotJson)) -logType $AutopilotLog -ErrorAction Stop
            Write-Output $ResponseLAUpload
        }

        # Cleanup the imported device records
        $deviceStatuses | ForEach-Object {
            Remove-AutoPilotImportedDevice -id $_.id
        }
}

Function Invoke-AutopilotSync(){

    $uri = "https://graph.microsoft.com/v1.0/deviceManagement/windowsAutopilotSettings/sync"
    try {
        $response = Invoke-RestMethod -Uri $uri -Headers $authToken -Method Post
        $response.Value
    }
    catch {

        $ex = $_.Exception
        $errorResponse = $ex.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($errorResponse)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd();

        Write-Host "Response content:`n$responseBody" -f Red
        Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"

        # break
    }

}


####################################################Functions for Log Analytics###################################################

Function New-Signature ($customerId, $sharedKey, $date, $contentLength, $method, $contentType, $resource) {
    $xHeaders = "x-ms-date:" + $date
    $stringToHash = $method + "`n" + $contentLength + "`n" + $contentType + "`n" + $xHeaders + "`n" + $resource

    $bytesToHash = [Text.Encoding]::UTF8.GetBytes($stringToHash)
    $keyBytes = [Convert]::FromBase64String($sharedKey)

    $sha256 = New-Object System.Security.Cryptography.HMACSHA256
    $sha256.Key = $keyBytes
    $calculatedHash = $sha256.ComputeHash($bytesToHash)
    $encodedHash = [Convert]::ToBase64String($calculatedHash)
    $authorization = 'SharedKey {0}:{1}' -f $customerId, $encodedHash
    return $authorization
}#endfunction
Function Send-LogAnalyticsData($customerId, $sharedKey, $body, $logType) {
    $method = "POST"
    $contentType = "application/json"
    $resource = "/api/logs"
    $rfc1123date = [DateTime]::UtcNow.ToString("r")
    $contentLength = $body.Length
    $signature = New-Signature `
        -customerId $customerId `
        -sharedKey $sharedKey `
        -date $rfc1123date `
        -contentLength $contentLength `
        -method $method `
        -contentType $contentType `
        -resource $resource
    
    $uri = "https://" + $customerId + ".ods.opinsights.azure.com" + $resource + "?api-version=2016-04-01"
    
    #validate that payload data does not exceed limits
    if ($body.Length -gt (31.9 *1024*1024))
    {
        throw("Upload payload is too big and exceed the 32Mb limit for a single upload. Please reduce the payload size. Current payload size is: " + ($body.Length/1024/1024).ToString("#.#") + "Mb")
    }

    $payloadsize = ("Upload payload size is " + ($body.Length/1024).ToString("#.#") + "Kb ")
    
    $headers = @{
        "Authorization"        = $signature;
        "Log-Type"             = $logType;
        "x-ms-date"            = $rfc1123date;
        "time-generated-field" = $TimeStampField;
    }
    $response = Invoke-WebRequest -Uri $uri -Method $method -ContentType $contentType -Headers $headers -Body $body -UseBasicParsing 
    $statusmessage = "$($response.StatusCode) : $($payloadsize)"
    return $statusmessage 
}#endfunction


####################################################Connect to Ressources###################################################

$global:totalCount = 0
$AutopilotZTDID=""
$AutopilotMDM=""

if ($WebhookData) 
{
#Define WorkspaceID
$WorkspaceID = Get-AutomationVariable -Name 'WorkspaceID'
$SharedKey = Get-AutomationVariable -Name 'WSSharedKey'
#Define Log Analytics Workspace Subscription ID
$SubscriptionID = Get-AutomationVariable -Name 'LASubscriptionID'
#Define Autopilot Import Log Name
$AutopilotLog = "Autopilot_Import"
# DO NOT DELETE TimeStampField - IT WILL BREAK LA Injection
$TimeStampField = "" 
Connect-AzAccount -Identity -Subscription $SubscriptionID
	
$WebhookData=(ConvertFrom-Json -InputObject $WebhookData)
#write-output $WebhookData.RequestBody
$Client=(ConvertFrom-Json -InputObject $WebhookData.RequestBody)
$serial=$client.SN
$GroupTag=$Client.GroupTag
$hash=$Client.Hash




	
####################################################Main logic Import###################################################

# Main logic Import

	Import-AutoPilotCSV -Serial $Serial -GroupTag $GroupTag -Hash $hash
    # Sync new devices to Intune
    Write-output "Triggering Sync to Intune."
    Invoke-AutopilotSync
}