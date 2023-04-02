param
(
[Parameter (Mandatory=$false)]
[object] $WebhookData
)

$GroupID="<INSERT Group ID HERE>"

Function Add-Member(){
    [cmdletbinding()]
    param
    (
       [Parameter(Mandatory=$true)] $ObjID
    )

        $DevUri = "https://graph.microsoft.com/beta/devices/" + $Objid
        $id = "@odata.id"
        $JSON = @{ $id="$DevUri" } | ConvertTo-Json -Compress
        $uri="https://graph.microsoft.com/beta/groups/$GroupID/members/`$ref"
		{Invoke-RestMethod -Uri $uri -Headers $authToken -Method Post -Body $JSON -ContentType "application/json"}		

}

Function Remove-Member(){
    [cmdletbinding()]
    param
    (
       [Parameter(Mandatory=$true)] $ObjID
    )

        $uri="https://graph.microsoft.com/beta/groups/$GroupID/members/$Objid/`$ref"
		{Invoke-RestMethod -Uri $uri -Headers $authToken -Method Delete}		


}

Function Get-AzureADDeviceByDevID(){
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$true)] $DEVID,
	[Parameter(Mandatory=$true)] $Action
)

        $uri = "https://graph.microsoft.com/beta/devices?`$filter=deviceId eq '$DEVID'"

    try {
        $response = (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).value
		If($Action -eq "OPTIN")
		{
		Add-Member -ObjID $response.id
		}
		If($Action -eq "OPTOUT")
		{
		Remove-Member -ObjID $response.id
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

    }

}


#######################################################################################################



#If runbook was called from Webhook, WebhookData will not be null
if ($WebhookData) 
{
    #GetAuthToken
    $resourceURL = "https://graph.microsoft.com/" 
    $response = [System.Text.Encoding]::Default.GetString((Invoke-WebRequest -UseBasicParsing -Uri "$($env:IDENTITY_ENDPOINT)?resource=$resourceURL" -Method 'GET' -Headers @{'X-IDENTITY-HEADER' = "$env:IDENTITY_HEADER"; 'Metadata' = 'True'}).RawContentStream.ToArray()) | ConvertFrom-Json 
    #$script:authToken = $response.access_token 

    $script:authToken = @{
        'Content-Type'  = 'application/json'
        'Authorization' = "Bearer " + $response.access_token
    }

    $WebhookData=(ConvertFrom-Json -InputObject $WebhookData)
    $Client=(ConvertFrom-Json -InputObject $WebhookData.RequestBody)
    $Action=$client.Action
    $Name=$client.Name
    $ID=$Client.ID
    If ($null -ne $ID)
    {
        If($Action -eq "OPTIN")
        {
            write-output "Adding Client: $Name with ID: $ID to Enablement group"
            Get-AzureADDeviceByDevID -DEVID $Client.ID -action $Action
        }
        If($Action -eq "OPTOUT")
        {
            write-output "Removing Client: $Name with ID: $ID to Enablement group"
            Get-AzureADDeviceByDevID -DEVID $Client.ID -action $Action
        }
    }  
    else
    {
        write-output "Nothing to do"
    }
}

