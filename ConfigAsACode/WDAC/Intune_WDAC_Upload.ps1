#Base Parameters
#Intune Policy ID
$ID="458e031a-b672-4cd4-acb4-a86f8ad4fb01"


# Connect to Intune
$Token= (Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com").Token
        
$script:authToken = @{
    'Content-Type'  = 'application/json'
    'Authorization' = "Bearer " + $Token
}

#Add the current WDAC Rule to the Policy
$FilePath = "$PSScriptRoot\Policies\WDACPolicy.bin"
$WDACBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($FilePath))

#RAW Intune Config Profile
$omaSettings = '[{"@odata.type":"#microsoft.graph.omaSettingBase64","omaUri":"./Vendor/MSFT/ApplicationControl/Policies/C98EDF68-041E-4DFE-AD89-D1FFF0F744D4/Policy","displayName":"WDAC Ruleset","value":"' + $WDACBase64 + '"}]'
   
$body = '{"@odata.type":  "#microsoft.graph.windows10CustomConfiguration","id":"' + $ID + '","roleScopeTagIds":["0"],"description":null,"displayName":"Pilot WDAC Ruleset","omaSettings":[{"@odata.type":"#microsoft.graph.omaSettingBase64","omaUri":"./Vendor/MSFT/ApplicationControl/Policies/C98EDF68-041E-4DFE-AD89-D1FFF0F744D4/Policy","displayName":"WDAC Ruleset","value":"' + $WDACBase64 + '"}]}'

Write-Output $body

# Restore the device configuration
try {
    Invoke-Restmethod -Method PATCH -Headers $authtoken -body $body -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations/$ID" -UseBasicParsing
    
}
catch {
    Write-Verbose "$deviceConfigurationDisplayName - Failed to restore Device Configuration" -Verbose
    Write-Error $_ -ErrorAction Continue
}


