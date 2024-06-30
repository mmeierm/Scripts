#########################################################################
## Azure automation runbook PowerShell script to automatically assign  ##
## Microsoft Intune Device Categories based on Inventory data          ##
#########################################################################

Add-Type -AssemblyName System.Web

####################################################
# Connect to Azure
$resourceURL = "https://graph.microsoft.com/" 
$response = [System.Text.Encoding]::Default.GetString((Invoke-WebRequest -UseBasicParsing -Uri "$($env:IDENTITY_ENDPOINT)?resource=$resourceURL" -Method 'GET' -Headers @{'X-IDENTITY-HEADER' = "$env:IDENTITY_HEADER"; 'Metadata' = 'True'}).RawContentStream.ToArray()) | ConvertFrom-Json 
#$script:authToken = $response.access_token 

$script:authToken = @{
    'Content-Type'  = 'application/json'
    'Authorization' = "Bearer " + $response.access_token
}

####################################################

Function AssignCategory(){
    [cmdletbinding()]
    param
    (
       [Parameter(Mandatory=$true)] $ObjID,
       [Parameter(Mandatory=$true)] $Category
    )
        $CategoryID = ($DeviceCategories | Where-Object -Property displayName -eq $Category).id
        $DevUri = "https://graph.microsoft.com/beta/deviceManagement/deviceCategories/" + $CategoryID
        $id = "@odata.id"
        $JSON = @{ $id="$DevUri" } | ConvertTo-Json -Compress

        $URI = "https://graph.microsoft.com/beta/deviceManagement/managedDevices('$ObjID')/deviceCategory/`$ref"
		Invoke-RestMethod -Uri $uri -Headers $authToken -Method PUT -Body $JSON -ContentType "application/json"	

}

####################################################

Write-Output "Export Device Categories"
$URI = "https://graph.microsoft.com/beta/deviceManagement/deviceCategories?`$select=id,displayName"
$Response = Invoke-WebRequest -Uri $URI -Method Get -Headers $authToken -UseBasicParsing 
$JsonResponse = $Response.Content | ConvertFrom-Json
$DeviceCategories = $JsonResponse.value
If ($JsonResponse.'@odata.nextLink')
{
    do {
        $URI = $JsonResponse.'@odata.nextLink'
        $Response = Invoke-WebRequest -Uri $URI -Method Get -Headers $authToken -UseBasicParsing 
        $JsonResponse = $Response.Content | ConvertFrom-Json
        $DeviceCategories += $JsonResponse.value
    } until ($null -eq $JsonResponse.'@odata.nextLink')
}

####################################################

Write-Output "Export Entra Devices"
# prepare Hashtable that will keep DeviceID as a key
$OptimizeDevices = @{}
$URI = "https://graph.microsoft.com/beta/devices?`$filter=accountEnabled eq true&`$select=id,deviceId,enrollmentProfileName,enrollmentType,mdmAppId,physicalIds"
$Response = Invoke-WebRequest -Uri $URI -Method Get -Headers $authToken -UseBasicParsing 
$JsonResponse = $Response.Content | ConvertFrom-Json
$EntraDeviceData = $JsonResponse.value
If ($JsonResponse.'@odata.nextLink')
{
    do {
        $URI = $JsonResponse.'@odata.nextLink'
        $Response = Invoke-WebRequest -Uri $URI -Method Get -Headers $authToken -UseBasicParsing 
        $JsonResponse = $Response.Content | ConvertFrom-Json
        $EntraDeviceData += $JsonResponse.value
    } until ($null -eq $JsonResponse.'@odata.nextLink')
}


foreach ($EntraDevice in $EntraDeviceData)
{
If($EntraDevice.mdmAppId -ne 'null')
{
    $EntraDevice = $EntraDevice | Select-Object -Property id,deviceId,enrollmentProfileName,enrollmentType,mdmAppId,trustType,managementType,physicalIds
    $OptimizeDevices.Add($Entradevice.deviceId,$EntraDevice)
}
} 

$EntraDeviceData =""
[system.gc]::Collect()


####################################################

Write-Output "Export Intune Devices"
$URI = "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$select=id,azureADDeviceId,deviceName,operatingSystem,model,joinType,userPrincipalName,isSupervised,deviceCategoryDisplayName"
$Response = Invoke-WebRequest -Uri $URI -Method Get -Headers $authToken -UseBasicParsing 
$JsonResponse = $Response.Content | ConvertFrom-Json
$IntuneData = $JsonResponse.value
If ($JsonResponse.'@odata.nextLink')
{
    do {
        $URI = $JsonResponse.'@odata.nextLink'
        $Response = Invoke-WebRequest -Uri $URI -Method Get -Headers $authToken -UseBasicParsing 
        $JsonResponse = $Response.Content | ConvertFrom-Json
        $IntuneData += $JsonResponse.value
    } until ($null -eq $JsonResponse.'@odata.nextLink')
}

####################################################

foreach ($IntuneDevice in $IntuneData)
{
    $neededCategory = $null
#################Windows#######################
    If ($IntuneDevice.operatingSystem -match "Windows")
        {
#################Windows-VDI###################
        If ($IntuneDevice.model -match "virtual Machine" -or $IntuneDevice.model -match "VMware") #VDI
            {
            #Match by Device Name
            If ($IntuneDevice.deviceName -match "CTX-VDI-")
                {
                    #Citrix onPrem VDI
                    $neededCategory = "VDI - Citrix onPrem"
                }
            elseIf ($IntuneDevice.deviceName -match "CTX-AZR")
                {
                    #Citrix Azure VDI
                    $neededCategory = "VDI - Citrix Azure"
                }

            }
        elseIf ($IntuneDevice.model -match "Cloud PC Enterprise")
            {
                #CloudPC Personal
                $neededCategory = "VDI - Cloud PC"
            }
        elseIf ($IntuneDevice.model -match "Cloud PC Frontline")
            {
                #CloudPC Personal (Frontline)
                $neededCategory = "VDI - Cloud PC Frontline"
            }
        else
#################Windows-physical##############
            {
            If ($IntuneDevice.deviceName -match "MTR-")
                {
                    #Microsoft Teams Rooms
                    $neededCategory = "Windows Teams Rooms Device"
                }
            elseIf ($IntuneDevice.model -eq "Hololens 2")
                {
                    #Hololens
                    $neededCategory = "Windows Hololens Device"
                }
            elseif($IntuneDevice.joinType -eq "azureADRegistered")
                {
                    #BYOD
                    $neededCategory = "Windows BYOD Device"
                }
            else
                {
                    #Match Enta Object to Intune Device to get more data
                    $Entraobject=$OptimizeDevices[$IntuneDevice.azureADDeviceID]
                    If($Entraobject.enrollmentProfileName -eq "DEV Client")
                        {
                            #DEVClient
                            $neededCategory = "Windows Developer Device"
                        }
                    elseif($Entraobject.physicalIds -match "BootToCloud")
                        {
                            #Windows 365 Boot GroupTag
                            $neededCategory = "Windows 365 Boot Device"
                        }
                    elseif($Entraobject.enrollmentProfileName -eq "Azure AD KIOSK Autopilot")
                        {
                            #Kiosk physical
                            $neededCategory = "Windows Kiosk Device"
                        }
                    else
                    {
                        #Standard Device
                        $neededCategory = "Windows Standard Device"
                    }
                }
            
            }#End of phyiscal
        }#End of Windows
#################MacOS#######################
    elseIf ($IntuneDevice.operatingSystem -match "macOS")
        {
        #Match Enta Object to Intune Device to get more data
        $Entraobject=$OptimizeDevices[$IntuneDevice.azureADDeviceID]
        If ($Entraobject.enrollmentProfileName -match "MacOS Default")
            {
            #MacOS FMC
            $neededCategory = "MacOS Standard Device"
            }
        elseIf($Entraobject.enrollmentProfileName -match "MacOS Dev")
            {
            #MacOS DEV
            $neededCategory = "MacOS Developer Device"
            }
        else
            {
            Write-Output "Unknown MacOS Device $($IntuneDevice.id)"
            }

        }#End MacOS
#################Android#######################
    elseIf ($IntuneDevice.operatingSystem -match "Android")
        {
        If ($IntuneDevice.userPrincipalName -match "Scanner-")
            {
            #Android BarcodeScanner
            $neededCategory = "Barcodescanner"
            }
        else
            {
            Write-Output "Unknown Android Device $($IntuneDevice.id)"
            }
        }#End Android
#################iOS/iPadOS#######################
    elseIf ($IntuneDevice.operatingSystem -match "iOS")
        {
        If ($IntuneDevice.userPrincipalName -match "Scanner-")
            {
            #iOS BarcodeScanner
            $neededCategory = "Barcodescanner"
            }
        elseif ($IntuneDevice.isSupervised -eq $false)
            {
            #BYOD
            $neededCategory = "iPhone BYOD"
            }
        else
            {
            #Match Enta Object to Intune Device to get more data
            $Entraobject=$OptimizeDevices[$IntuneDevice.azureADDeviceID]
            If ($Entraobject.enrollmentProfileName -match "Default iOS")
                {
                #Default iOS
                $neededCategory = "Company iPhone"
                }
            elseIf($Entraobject.enrollmentProfileName -match "Default Kiosk")
                {
                #iOS Kiosk / Shared
                $neededCategory = "Kiosk iPad"
                }
            else
                {
                #personalized iPhone w/o enrollment profile name
                $neededCategory = "Personalized iPhone"
                }
            }
        }#End iOS
#################Unknown#######################
    else
        {
        Write-Output "Unknown Platform $($IntuneDevice.id)"
        }

#################Assign Category###############
    If ($null -ne $neededCategory -and $neededCategory -ne $IntuneDevice.deviceCategoryDisplayName)
    {
    Write-Output "Assigning $neededCategory to $($IntuneDevice.deviceName)"
    AssignCategory -ObjID $IntuneDevice.id -Category $neededCategory
    }


} 

