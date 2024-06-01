param
(
[parameter(Mandatory=$false)]
$Mode,
[Parameter (Mandatory=$false)]
[object] $WebhookData
)

#######Parameters######
$AllowedGroupIDs="<INSERT AllowedGroup ID HERE>"
$Tenant = "<INSERT Tenant ID HERE>"
$Subscription = "<INSERT Subscription ID HERE>"
$StorageName = "<INSERT Storage Account Name HERE>"
$RG = "<INSERT ResourceGroup Name HERE>"
$Tablename = "<INSERT Tablename HERE>"

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

Function Get-AzureADDeviceByDevID(){
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$true)] $DEVID
)

        $uri = "https://graph.microsoft.com/beta/devices?`$filter=deviceId eq '$DEVID'"

    try {
        $response = (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).value
		return $response.id
           
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

    }

}


#######################################################################################################
try
{
    "Logging in to Azure..."
    Connect-AzAccount -Identity -Tenant $tenant -Subscription $Subscription
	Set-AzContext -Subscription $Subscription
	$ctx=(Get-AzStorageAccount -Name $StorageName -ResourceGroupName $RG).Context
	$StorageTable = Get-AzStorageTable -Name $Tablename -Context $ctx
	$CloudTable = $StorageTable.CloudTable
}
catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
}


    #GetAuthToken
    $resourceURL = "https://graph.microsoft.com/" 
    $response = [System.Text.Encoding]::Default.GetString((Invoke-WebRequest -UseBasicParsing -Uri "$($env:IDENTITY_ENDPOINT)?resource=$resourceURL" -Method 'GET' -Headers @{'X-IDENTITY-HEADER' = "$env:IDENTITY_HEADER"; 'Metadata' = 'True'}).RawContentStream.ToArray()) | ConvertFrom-Json 
    #$script:authToken = $response.access_token 

    $script:authToken = @{
        'Content-Type'  = 'application/json'
        'Authorization' = "Bearer " + $response.access_token
    }

#######################################################################################################

If($Mode -eq "CleanUP") #CleanUP Task will run scheduled and automatically remove devices from their groups after the duration is expired
{
	write-output "Running in CleanUp Mode"
    #Check Table for devices to remove
	
	#Get Auth Key for Storage
	$AccountKey = $StorageTable.Context.TableStorageAccount.Credentials.Key
	$RequestURI = $StorageTable.CloudTable.URI.AbsoluteUri
	
	# Define the date in RFC 1123 format
	$Date = [System.DateTime]::UtcNow.ToString("R")

	# Create the signature string
	$StringToSign = "$Date`n/$StorageName/$TableName"
	$UTF8Encoding = New-Object System.Text.UTF8Encoding
	$SignatureBytes = $UTF8Encoding.GetBytes($StringToSign)
	$HMACSHA256 = New-Object System.Security.Cryptography.HMACSHA256
	$HMACSHA256.Key = [System.Convert]::FromBase64String($AccountKey)
	$Signature = $HMACSHA256.ComputeHash($SignatureBytes)
	$EncodedSignature = [System.Convert]::ToBase64String($Signature)

	# Define the headers
	$Headers = @{
		"x-ms-date" = $Date
		"x-ms-version" = "2020-08-04"
		"Authorization" = "SharedKeyLite " + $StorageName + ":" + $EncodedSignature
		"Accept" = "application/json;odata=nometadata"
	}

	# Perform the REST API call
	$devices = (Invoke-RestMethod -Uri $RequestURI -Method Get -Headers $Headers).value
	
	#Read all entries from Azure Table Storage
	$today = Get-Date -Format o
	foreach($device in $devices)
	{
		If($Device.Removeafter -lt $today)
		{
			write-output "Removing Device $($Device.DeviceName) from Group $($Device.GroupID) since date to remove is due: $($device.removeafter)"
			Remove-Member -ObjID $Device.PartitionKey -GroupID $Device.GroupID
			Remove-AzTableRow -table $cloudTable -PartitionKey $Device.PartitionKey -RowKey $Device.RowKey
		}
		else
		{
			write-output "Ignoring Device $($Device.DeviceName) since the date to remove is not yet reached $($device.removeafter)"
		}
	}
}

elseif ($WebhookData) #If runbook was called from Webhook, WebhookData will not be null #Logic to add devices to groups and write to Azure Table Storage
{
	write-output "Running in Webhook Mode"
    $WebhookData=(ConvertFrom-Json -InputObject $WebhookData)
    $Client=(ConvertFrom-Json -InputObject $WebhookData.RequestBody)
    $Name = $client.Name
    $DEVID = $Client.ID
	$Duration = $Client.Duration
	$GroupID = $Client.GroupID
	$guidRegex = '^[{(]?[0-9A-Fa-f]{8}-([0-9A-Fa-f]{4}-){3}[0-9A-Fa-f]{12}[)}]?$' #Check if IDs are valid GUIDS

    If ($null -ne $DEVID -and $AllowedGroupIDs -contains $GroupID -and $DEVID -match $guidRegex -and $GroupID -match $guidRegex)
    {
		switch ($Duration)                         
		{                        
			"1 Day" {$Removeafter = (Get-Date -Date (Get-date).AddDays(+1) -Format o)}                        
			"3 Days" {$Removeafter = (Get-Date -Date (Get-date).AddDays(+3) -Format o)}                       
			"7 Days" {$Removeafter = (Get-Date -Date (Get-date).AddDays(+7) -Format o)}                        
			Default {$Removeafter = $null}                        
		}
		If ($Removeafter -ne $null)
			{
			write-output "Adding Client: $Name with DevID: $DEVID for $Duration day(s) to Enablement group"
			$ObjID=Get-AzureADDeviceByDevID -DEVID $DEVID
			#Add Entry to Table
			Add-AzTableRow -table $cloudTable -partitionKey $ObjId -rowKey ("$DEVID") -property @{"DeviceName"="$Name";"GroupID"="$GroupID";"Removeafter"="$Removeafter"}
			#Add Device to Group
			Add-Member -ObjID $ObjID -GroupID $GroupID
			}
		else
		{
			Write-Error "Invalid Duration"
		}
    }  
    else
    {
        write-Error "Invalid Input"
    }
}
else
{
	write-Error "Invalid Mode Selected"
}
