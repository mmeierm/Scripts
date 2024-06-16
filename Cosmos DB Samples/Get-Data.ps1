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

####################################################Get Data#############################################

$Verb = "GET"
$ResourceType = "docs";
$ResourceLink = "dbs/$DatabaseId/colls/$CollectionId"
$queryUri = "$CosmosDBEndPoint$ResourceLink/docs"
$dateTime = [DateTime]::UtcNow.ToString("r")
$authHeader = Generate-MasterKeyAuthorizationSignature -verb $Verb -resourceLink $ResourceLink -resourceType $ResourceType -key $MasterKey -keyType "master" -tokenVersion "1.0" -dateTime $dateTime
$header = @{authorization=$authHeader;"x-ms-version"="2018-12-31";"x-ms-date"=$dateTime;"x-ms-max-item-count"="1000"}

	

	
$Response=Invoke-WebRequest -Method $Verb -Uri $queryUri -Headers $header -ErrorAction SilentlyContinue -UseBasicParsing
$JsonResponse = $Response.Content | ConvertFrom-Json
$CosmosDBData = $JsonResponse.Documents
$NextToken = $Response.Headers.'x-ms-continuation'

    
while ($NextToken)
{
    $header = @{authorization=$authHeader;"x-ms-version"="2018-12-31";"x-ms-date"=$dateTime;"x-ms-max-item-count"="1000";"x-ms-continuation"=$NextToken}

    $Response=Invoke-WebRequest -Method $Verb -Uri $queryUri -Headers $header -ErrorAction SilentlyContinue -UseBasicParsing
    $JsonResponse = $Response.Content | ConvertFrom-Json
    $CosmosDBData += $JsonResponse.Documents
    $NextToken = $Response.Headers.'x-ms-continuation'
}
Write-Output "CosmosDB found entries: $($CosmosDBData.Count)"
Write-Output $CosmosDBData
