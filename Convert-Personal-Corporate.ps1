
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

Function Get-PersonalDevices() {

            $uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$select=id,managedDeviceOwnerType,serialNumber,operatingSystem&`$filter=managedDeviceOwnerType eq 'personal' and operatingSystem eq 'Windows'"
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

function Set-DeviceOwnerTypeCorporate() {
    param (
        $DEVID
    )
    
    try {
        $uri = "https://graph.microsoft.com/beta/deviceManagement/manageddevices/$DEVID"
        $Body = @{"managedDeviceOwnerType"="company"} | ConvertTo-Json
        $response = (Invoke-RestMethod -Uri $uri -Headers $authToken -Method PATCH -Body $Body -ContentType "application/json")
    
        return $response
    }
    catch {
        Write-output "Error : $($error[0].exception.message)"
    }
}


####################################################

$Devices = Get-PersonalDevices

Foreach ($Device in $Devices){
$ID=$Device.ID
$OS=$Device.operatingSystem
$SN=$Device.serialNumber
If ($OS -eq "Windows")
{
    Write-output "Setting $OS Device with Serial: $SN and ID $ID to Ownertype Cororate"
Set-DeviceOwnerTypeCorporate -DEVID $ID
}



}
