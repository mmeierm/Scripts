using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."
Add-Type -AssemblyName System.Web
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
		[Parameter(Mandatory=$true)][String]$CollectionId,
		[Parameter(Mandatory=$true)][String]$JSON
	)
try {
$EndPoint = "<INSERT Database URL here>"
$DataBaseId = "InventoryDatabase"
$MasterKey = "<INSERT Primary Database Key here>"
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
		[Parameter(Mandatory=$true)][String]$CollectionId,
		[Parameter(Mandatory=$true)][String]$JSON
	)
$EndPoint = "<INSERT Database URL here>"
$DataBaseId = "InventoryDatabase"
$MasterKey = "<INSERT Primary Database Key here>"
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

	$result=Invoke-RestMethod -Method $Verb -ContentType $contentType -Uri $queryUri -Headers $header -Body $bodydecoded -ErrorAction SilentlyContinue
    return $result.statuscode
    
	
}

# Interact with query parameters or the body of the request.
$In=$Request.Body | ConvertFrom-Json


$CollectionId = $In.CollectionId
$JSON = $in.JSON

    $JSON= [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String($JSON))

$Result=Post-CosmosDb  -CollectionId $CollectionId -JSON $JSON
If ($Result -eq "409")
{
$Result=Replace-CosmosDb -CollectionId $CollectionId -JSON $JSON
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Body = $Result
})
