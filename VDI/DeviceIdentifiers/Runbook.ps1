param
(
[Parameter (Mandatory=$false)]
[object] $WebhookData
)


#######################################################################################################
    #GetAuthToken
    $resourceURL = "https://graph.microsoft.com/" 
    $response = [System.Text.Encoding]::Default.GetString((Invoke-WebRequest -UseBasicParsing -Uri "$($env:IDENTITY_ENDPOINT)?resource=$resourceURL" -Method 'GET' -Headers @{'X-IDENTITY-HEADER' = "$env:IDENTITY_HEADER"; 'Metadata' = 'True'}).RawContentStream.ToArray()) | ConvertFrom-Json 

    $script:authToken = @{
        'Content-Type'  = 'application/json'
        'Authorization' = "Bearer " + $response.access_token
    }

#######################################################################################################
if ($WebhookData) 
{
	write-output "Running in Webhook Mode"
    $WebhookData=(ConvertFrom-Json -InputObject $WebhookData)
    $Client=(ConvertFrom-Json -InputObject $WebhookData.RequestBody)
    $Manufactuer = $client.Manufactuer
    $Model = $Client.Model
	  $Serial = $Client.Serial
	


    If ($null -ne $Manufactuer -and $null -ne $Model -and $null -ne $Model)
    {
    $body=@"
{
  "overwriteImportedDeviceIdentities": false,
  "importedDeviceIdentities": [
    {
      "importedDeviceIdentityType": "manufacturerModelSerial",
      "importedDeviceIdentifier": "$Manufactuer, $Model, $Serial"
    }
  ]
}
"@

    
    Invoke-WebRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/importedDeviceIdentities/importDeviceIdentityList" -Body $body -Method Post -UseBasicParsing               
		}

}
else
{
	write-Error "Not started from Webhook"
}
