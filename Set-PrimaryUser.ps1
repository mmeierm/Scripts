
####################################################
    # Connect to Intune
    $resourceURL = "https://graph.microsoft.com/" 
    $response = [System.Text.Encoding]::Default.GetString((Invoke-WebRequest -UseBasicParsing -Uri "$($env:IDENTITY_ENDPOINT)?resource=$resourceURL" -Method 'GET' -Headers @{'X-IDENTITY-HEADER' = "$env:IDENTITY_HEADER"; 'Metadata' = 'True'}).RawContentStream.ToArray()) | ConvertFrom-Json 
    #$script:authToken = $response.access_token 
    
    $script:authToken = @{
        'Content-Type'  = 'application/json'
        'Authorization' = "Bearer " + $response.access_token
    }
    
    
    ####################################################

Function Get-VirtualDevices() {

			
            $uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=startswith(deviceName,'VM-')&`$select=id,usersLoggedOn"
            $DevicesResponse = (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get)
            $Devices += $DevicesResponse.value
            $DevicesNextLink = $DevicesResponse."@odata.nextLink"
            while ($null -ne $DevicesNextLink) {
                $DevicesResponse = (Invoke-RestMethod -Uri $DevicesNextLink -Headers $authToken -Method Get)
                $DevicesNextLink = $DevicesResponse."@odata.nextLink"
                $Devices += $DevicesResponse.value
            }

            
            <#
			$uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=model eq 'Virtual Machine'&`$select=id,usersLoggedOn"
            $DevicesResponse = (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get)
            $Devices += $DevicesResponse.value
            $DevicesNextLink = $DevicesResponse."@odata.nextLink"
            while ($null -ne $DevicesNextLink) {
                $DevicesResponse = (Invoke-RestMethod -Uri $DevicesNextLink -Headers $authToken -Method Get)
                $DevicesNextLink = $DevicesResponse."@odata.nextLink"
                $Devices += $DevicesResponse.value
            }
			#>

            return $Devices
}

function Set-PrimaryUser() {
    param (
        $DEVID,
        $USR
    )
    
    try {
        $uri = "https://graph.microsoft.com/beta/deviceManagement/manageddevices('$DEVID')/users/`$ref"
        $USRUri = "https://graph.microsoft.com/beta/users/" + $USR
        $id = "@odata.id"
        $Body = @{ $id="$USRUri" } | ConvertTo-Json -Compress
        $response = (Invoke-RestMethod -Uri $uri -Headers $authToken -Method POST -Body $Body -ContentType "application/json")
        return $response
    }
    catch {
        Write-output "Error : $($error[0].exception.message)"
    }
}

function Get-PrimaryUser() {
    param (
        $DEVID
    )
    try {
        $uri = "https://graph.microsoft.com/beta/deviceManagement/manageddevices('$DEVID')/users"
        $DevicesResponse = (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get)
        $User = $DevicesResponse.value.id
        return $User
    }
catch {
    Write-output "Error : $($error[0].exception.message)"
}
}

####################################################

$Devices = Get-VirtualDevices

Foreach ($Device in $Devices){
    $ID=$Device.ID
    $loggedonUser=$Device.usersLoggedOn.userId | Select-Object -Last 1
	Write-output "Checking Device $ID with LoggedonUser $loggedonUser"
    $PrimUser=Get-PrimaryUser -DEVID $ID
	Write-output "Got PrimaryUser of Device $ID with ID $PrimUser"

    If(($null -ne $loggedonUser) -and ($loggedonUser -ne $PrimUser))
    {
		Write-output "LoggedonUser is different from Primary User, setting Primary User"
        Set-PrimaryUser -DEVID $ID -USR $loggedonUser
    }
	Write-output ""
	Write-output "################################################################################"
	Write-output ""
}
