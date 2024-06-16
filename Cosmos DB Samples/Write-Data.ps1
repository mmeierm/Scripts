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

######################################################
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
                    Start-Sleep 1
                    $DeviceResult=Post-CosmosDb -EndPoint $EndPoint -DataBaseId $DataBaseId -CollectionId $CollectionId -MasterKey $MasterKey -JSON $JSON
                }
            }
        elseif ($DeviceResult -eq "429")
            {
                Start-Sleep 1
                $DeviceResult=Replace-CosmosDb -EndPoint $EndPoint -DataBaseId $DataBaseId -CollectionId $CollectionId -MasterKey $MasterKey -JSON $JSON
            }
}


##################################################################################################################################################################

# Send Sample Data to the Cosmos dB
$Data = New-Object System.Object
$Data | Add-Member -MemberType NoteProperty -Name "id" -Value $(New-GUID) -Force
$Data | Add-Member -MemberType NoteProperty -Name "Property1" -Value "Value1"  -Force
$Data | Add-Member -MemberType NoteProperty -Name "Property2" -Value "Value2" -Force
$Datajson = $Data | ConvertTo-Json


# Submit the data to the API endpoint
$DeviceResult=Post-CosmosDb -EndPoint $CosmosDBEndPoint -DataBaseId $DataBaseId -CollectionId $collectionId -MasterKey $MasterKey -JSON $Datajson