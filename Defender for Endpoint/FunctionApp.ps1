# Input bindings are passed in via param block.
param($Timer)

####################################Token Section##############################################
Write-Output "Connect to Intune and AAD"
$Token= [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR((Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com" -AsSecureString).Token))
$script:authToken = @{
    'Content-Type'  = 'application/json'
    'Authorization' = "Bearer " + $Token
}

Write-Output "Connect to MDE"
$Token= [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR((Get-AzAccessToken -ResourceUrl "https://api.securitycenter.microsoft.com" -AsSecureString).Token))
$script:authTokenMDE= @{
    'Content-Type'  = 'application/json'
    'Authorization' = "Bearer " + $TokenMDE
}

####################################Function Section##############################################

Function Get-ManagedDevices(){

try {

        $uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$select=id,azureADDeviceId,userId,userPrincipalName,usersLoggedOn"

    $DevicesResponse = (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get)

    $Devices = $DevicesResponse.value

    $DevicesNextLink = $DevicesResponse."@odata.nextLink"

        while ($null -ne $DevicesNextLink){

            $DevicesResponse = (Invoke-RestMethod -Uri $DevicesNextLink -Headers $authToken -Method Get)
            $DevicesNextLink = $DevicesResponse."@odata.nextLink"
            $Devices += $DevicesResponse.value

        }

    return $Devices
    }

    catch {

    $ex = $_.Exception
    $errorResponse = $ex.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($errorResponse)
    $reader.BaseStream.Position = 0
    $reader.DiscardBufferedData()
    $responseBody = $reader.ReadToEnd();
    Write-Host "Response content:`n$responseBody" -f Red
    Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
    write-host
    break

    }

}
Function Get-MDEDevices(){

try {

        $uri = "https://api.securitycenter.microsoft.com/api/machines?`$select=id,aadDeviceId,machineTags"

    $DevicesResponse = (Invoke-RestMethod -Uri $uri -Headers $authTokenMDE -Method Get)

    $Devices = $DevicesResponse.value

    $DevicesNextLink = $DevicesResponse."@odata.nextLink"

        while ($null -ne $DevicesNextLink){

            $DevicesResponse = (Invoke-RestMethod -Uri $DevicesNextLink -Headers $authTokenMDE -Method Get)
            $DevicesNextLink = $DevicesResponse."@odata.nextLink"
            $Devices += $DevicesResponse.value

        }

    return $Devices
    }

    catch {

    $ex = $_.Exception
    $errorResponse = $ex.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($errorResponse)
    $reader.BaseStream.Position = 0
    $reader.DiscardBufferedData()
    $responseBody = $reader.ReadToEnd();
    Write-Host "Response content:`n$responseBody" -f Red
    Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
    write-host
    break

    }

}

Function Get-Users(){

try {

        $uri = "https://graph.microsoft.com/beta/users/?`$filter=userType+eq+%27Member%27&`$select=id%2cuserPrincipalName%2ccompanyName%2cusageLocation"

    $DevicesResponse = (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get)

    $Devices = $DevicesResponse.value

    $DevicesNextLink = $DevicesResponse."@odata.nextLink"

        while ($null -ne $DevicesNextLink){

            $DevicesResponse = (Invoke-RestMethod -Uri $DevicesNextLink -Headers $authToken -Method Get)
            $DevicesNextLink = $DevicesResponse."@odata.nextLink"
            $Devices += $DevicesResponse.value

        }

    return $Devices
    }

    catch {

    $ex = $_.Exception
    $errorResponse = $ex.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($errorResponse)
    $reader.BaseStream.Position = 0
    $reader.DiscardBufferedData()
    $responseBody = $reader.ReadToEnd();
    Write-Host "Response content:`n$responseBody" -f Red
    Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
    write-host
    break

    }

}

Function Set-MDEDeviceTag(){
    [cmdletbinding()]
    param
    (
        $id,
        $newTag,
        $RetryCount = 5
    )

        $uri = "https://api.securitycenter.microsoft.com/api/machines/$id/tags"

        $body = @{
        "Value"=$newTag;
        "Action"="Add";
        }


        try {
            $response = Invoke-RestMethod -Method Post -Uri $uri -ContentType "application/json" -Headers $authTokenMDE -Body ($body|ConvertTo-Json) 
        } catch {
            $StatusCode = [int]$_.Exception.Response.StatusCode
        
            if ($StatusCode -eq 429) {
                Write-Output "Request ended with Error 429 and trying again after 30s"
                Start-Sleep -Seconds 30
                return Set-MDEDeviceTag -id $id -newTag $newTag -RetryCount ($RetryCount - 1)
            } 
             else {
                Write-Error "Set-MDEDeviceTag, expected 200, got $([int]$StatusCode)"
            }
        } 
        
}

Function Remove-MDEDeviceTag(){
    [cmdletbinding()]
    param
    (
        $id,
        $RemoveTag,
        $RetryCount = 5
    )

        $uri = "https://api.securitycenter.microsoft.com/api/machines/$id/tags"

        $body = @{
        "Value"=$RemoveTag;
        "Action"="Remove";
        }

        try {
            $response = Invoke-RestMethod -Method Post -Uri $uri -ContentType "application/json" -Headers $authTokenMDE -Body ($body|ConvertTo-Json) 
        } catch {
            $StatusCode = [int]$_.Exception.Response.StatusCode
        
            if ($StatusCode -eq 429) {
                Write-Output "Request ended with Error 429 (TooManyRequests) and trying again after 30s"
                Start-Sleep -Seconds 30
                return Remove-MDEDeviceTag -id $id -RemoveTag $RemoveTag -RetryCount ($RetryCount - 1)
            } 
             else {
                Write-Error "Remove-MDEDeviceTag, expected 200, got $([int]$StatusCode)"
            }
        }
        
}

function Remove-Diacritics {
    param (
        [String]$sToModify = [String]::Empty
    )

    foreach ($s in $sToModify) {
        # Param may be a string or a list of strings
        if ($sToModify -eq $null) { return [string]::Empty }
        $sNormalized = $sToModify.Normalize("FormD")

        foreach ($c in [Char[]]$sNormalized) {
            $uCategory = [System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($c)
            if ($uCategory -ne "NonSpacingMark") { $res += $c }
        }

        return $res
    }
}

##############################Main Section####################################################


Write-Output "Get MDE Devices"
$MDEDevices=Get-MDEDevices

Write-Output "Get Intune Devices"
$IntuneDevices=Get-ManagedDevices
# prepare Hashtable that will keep ObjectID as a key
$OptimizeIntuneDevices = @{}
foreach ($_ in $IntuneDevices) {
    If ($_.azureADDeviceId -ne "00000000-0000-0000-0000-000000000000")
    {
        $OptimizeIntuneDevices.Add($_.azureADDeviceId,$_)
    }
    
}
# End of Hashtable

Write-Output "Get AAD Users"
$AADUsers=Get-Users
# prepare Hashtable that will keep ObjectID as a key
$OptimizeAADUsers = @{}
foreach ($_ in $AADUsers) {
    $OptimizeAADUsers.Add($_.id,$_)
}
# End of Hashtable


$currentTags=@()

Write-output "Starting enumerating Devices"

################################Loop through all MDE Devices#######################################
foreach ($MDEDevice in $MDEDevices)
{
    ################################Start searching for the device properties in Intune and Entra################################
    $MDEDeviceid=$MDEDevice.id
    #Get the current Tags to check if we need to do something
    $currentTags = $MDEDevice.machineTags
    try {
        $IntuneDevice = $OptimizeIntuneDevices[$MDEDevice.aadDeviceId]
    }
    catch {
        $IntuneDevice = $null
    }
    
    #Check if we found a device in Intune with the matiching aadDeviceID
    If ($IntuneDevice)
    {
        #Reset Intune User Varible
        $IntuneUser=""

        #Reset Userfound variable to false, to check if we are able to find a correlated user in Intune
        $userfound=$false
            
        #Check if the Intune Device has an "Enrolled by" User, if yes we will use this one, else we will try to use the "usersLoggedOn" user
        If ($IntuneDevice.userId -eq "")
        {
            try {
                $IntuneUser=$IntuneDevice.usersLoggedOn.userid[0]
            }
            catch {
                Write-Output "User assignment not possible as no logged on users available"
            }
        }
        else
        {
        $IntuneUser=$IntuneDevice.userId
        }
        #Check if we found an Intune User to check if we need to apply a Tag based on a users location
        If ($IntuneUser -ne "")
        {   
            $AADUser=$OptimizeAADUsers[$IntuneUser]
            If ($AADUser)
            {
                #Since the request matches, we can set the Userfound Variable to true and we can move on with setting the appropiate DeviceTag
                $userfound=$true

                #Check if the Company Name is not empty
                If ($null -ne $AADUser.companyName)
                {
                    #Remove special characters
                    $CName = Remove-Diacritics $AADUser.companyName
                    $CName = $CName.replace(',','_')
                }
                else 
                {
                    $CName = "Unknown"
                }
                
                #Define what Tag we would expect the device to have
                $neededTag = "Company: " + $CName

            }
        }

        #If we have not found a user in Intune we will set a generic Tag for these devices
        If (!($userfound))
        {
                #Define what Tag we would expect the device to have, in this case a dummy Tag for Intune managed Devices without useable user
                $neededTag = "Company: Unknown" 
        }

################################At this point we figured out what Tags should be assigned => Start assignment################################

        #Check if the device already has the needed Tag
        If ($currentTags -like "*$neededTag*")
        {
            Write-output "MDEDevice with ID: $MDEDeviceid is already up to date with the following Tags: $currentTags"
            #Check if other managed Tags are assigned that we need to remove
            [system.array]$modified = $null
            foreach ($currentTag in $currentTags)
            {
                If (($currentTag -like "*Company:*" -or $currentTag -like "*Decommissioned*") -and $currentTag -ne $neededTag)
                {
                    [system.array]$modified+=$currentTag
                }
            }
            #If we found a existing Tag, we should remove it before applying a new one
            If ($null -ne $modified)
            {
                foreach($mod in $modified)
                {
                    Write-output "Removing additional Tags of MDEDevice with ID $MDEDeviceid, removing $mod"
                    Remove-MDEDeviceTag -id $MDEDeviceid -RemoveTag $mod
                }
            }
        }
        else
        {
            #Since the Device is not in the expected state we have to check if the device has already another Tag assigned that needs to be removed
            [system.array]$modified = $null
            foreach ($currentTag in $currentTags)
            {
                If ($currentTag -like "*Company:*" -or $currentTag -like "*Decommissioned*")
                {
                    [system.array]$modified+=$currentTag
                }
            }
            #If we found a existing Tag, we should remove it before applying a new one
            If ($null -ne $modified)
                {
                    Write-output "Updating MDEDevice with ID $MDEDeviceid with currently the following Tags: $currentTags Removing $modified and adding: $neededTag"
                    foreach($mod in $modified)
                    {
                        Remove-MDEDeviceTag -id $MDEDeviceid -RemoveTag $mod
                    }
                        Set-MDEDeviceTag -id $MDEDeviceid -newTag $neededTag
                }
            else
                {
                    Write-output "Updating MDEDevice with ID $MDEDeviceid with currently the following Tags: $currentTags that does not contain a Location to have the following Tags: $neededTag"
                    Set-MDEDeviceTag -id $MDEDeviceid -newTag $neededTag
                }
        }                 
    }
    else #Device not found in Intune, checking wheter it has a Company Tag assigned and we should assign the decomissioned Tag
    {
        If ($currentTags -like "*Company:*")
        {
            $neededTag = "Decommissioned" 
            [system.array]$removing=$null
            foreach ($currentTag in $currentTags)
            {
                If ($currentTag -like "*Company:*")
                {
                    [system.array]$removing+=$currentTag
                }
            }
            foreach($remove in $removing)
            {
                Remove-MDEDeviceTag -id $MDEDeviceid -RemoveTag $remove
            }
            Set-MDEDeviceTag -id $MDEDeviceid -newTag $neededTag
            Write-Output "Did no longer find previously managed MDE device with ID $MDEDeviceid in Intune, removing old Tags $remove and assigning new Tag $neededTag."
        }
            
    }    
}
