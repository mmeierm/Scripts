$GroupID="<INSERT Group ID HERE>"
$enrolledDateTime = "<INSERT targeted enrollementDateTime>" #Enter enrollementDateTime in Format 2024-01-21T10:18:19Z after which devices should be automatically added to the Group

##############################################################################################################################


#GetAuthToken
    $resourceURL = "https://graph.microsoft.com/" 
    $response = [System.Text.Encoding]::Default.GetString((Invoke-WebRequest -UseBasicParsing -Uri "$($env:IDENTITY_ENDPOINT)?resource=$resourceURL" -Method 'GET' -Headers @{'X-IDENTITY-HEADER' = "$env:IDENTITY_HEADER"; 'Metadata' = 'True'}).RawContentStream.ToArray()) | ConvertFrom-Json 
    #$script:authToken = $response.access_token 

    $script:authToken = @{
        'Content-Type'  = 'application/json'
        'Authorization' = "Bearer " + $response.access_token
    }

##############################################################################################################################



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
		Invoke-RestMethod -Uri $uri -Headers $authToken -Method Post -Body $JSON -ContentType "application/json"	

}

Function Get-Members(){


        $uri="https://graph.microsoft.com/beta/groups/$GroupID/members?`$select=id,deviceId"
		$members=Invoke-RestMethod -Uri $uri -Headers $authToken -Method GET -ContentType "application/json"	
        return $members.value
}

Function Remove-Member(){
    [cmdletbinding()]
    param
    (
       [Parameter(Mandatory=$true)] $ObjID
    )

        $uri="https://graph.microsoft.com/beta/groups/$GroupID/members/$Objid/`$ref"
		Invoke-RestMethod -Uri $uri -Headers $authToken -Method Delete


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

Function Get-ManagedDevicesbyEnrollmentDate() {

 
    try {
            $uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices?filter=(enrolleddatetime gt $enrolledDateTime)&`$select=id,azureADDeviceId,enrolledDateTime,operatingSystem"
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



############################################################################################################################################

$Members=(Get-Members).deviceid
$NewMembers=get-ManagedDevicesbyEnrollmentDate

foreach ($NewMember in $NewMembers)

{
    If (!($Members -match $($NewMember.azureADDeviceId)))
    {
            write-output "Adding Client: with ID: $($NewMember.ID) and Entra Device ID: $($NewMember.azureADDeviceId) to group"
            Get-AzureADDeviceByDevID -DEVID $($NewMember.azureADDeviceId) -action "OPTIN"

    }
}




