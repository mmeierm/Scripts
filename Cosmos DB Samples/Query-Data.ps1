[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$CosmosDBEndPoint = "<INSERT Database URL here>"
$DatabaseId = "<INSERT Database Name here>"
$collectionId = "<INSERT Collection Name here>"
$MasterKey = "<INSERT Database Master Key here>"


# add necessary assembly
#
Add-Type -AssemblyName System.Web

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

####################################################Query Data#############################################
# Set the query
$body = @"
{  
  "query": "SELECT * FROM c where c.id = '15aed94b-ab97-4b22-8adb-da1dcf6ec2e1'",  
  "parameters": []  
}
"@

$resourceType = "docs"
$resourceLink = "dbs/$databaseId/colls/$collectionId"
$dateTime = [DateTime]::UtcNow.ToString("r")
$verb = "POST"

$authHeader = Generate-MasterKeyAuthorizationSignature -verb $verb -resourceLink $resourceLink -resourceType $resourceType -key $masterKey -keyType "master" -tokenVersion "1.0" -dateTime $dateTime
$header = @{authorization=$authHeader;"x-ms-documentdb-isquery"=$true;"x-ms-version"="2018-12-31";"x-ms-date"=$dateTime;"x-ms-documentdb-query-enablecrosspartition"=$true}


# Create the URI for the query
$ResourceLink = "dbs/$DatabaseId/colls/$CollectionId"
$uri = "$cosmosDbEndpoint$ResourceLink/docs"

# Execute the query
$Response=Invoke-WebRequest -Method Post -Uri $uri -Headers $header -ErrorAction SilentlyContinue -UseBasicParsing -ContentType "application/query+json" -Body $body
$JsonResponse = $Response.Content | ConvertFrom-Json
$CosmosDBData = $JsonResponse.Documents
$NextToken = $Response.Headers.'x-ms-continuation'

    
while ($NextToken)
{
    $header = @{authorization=$authHeader;"x-ms-documentdb-isquery"=$true;"x-ms-version"="2018-12-31";"x-ms-date"=$dateTime;"x-ms-documentdb-query-enablecrosspartition"=$true;"x-ms-continuation"=$NextToken}

    $Response=Invoke-WebRequest -Method Post -Uri $uri -Headers $header -ErrorAction SilentlyContinue -UseBasicParsing -ContentType "application/query+json" -Body $body
    $JsonResponse = $Response.Content | ConvertFrom-Json
    $CosmosDBData += $JsonResponse.Documents
    $NextToken = $Response.Headers.'x-ms-continuation'
}
Write-Output "CosmosDB found entries: $($CosmosDBData.Count)"
Write-Output $CosmosDBData