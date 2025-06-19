#Base Parameters
#Intune Policy Name
$PolicyName = 'Pilot App Control for Business Policy'


# Connect to Intune
$Token= [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR((Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com" -AsSecureString).Token))
        
$script:authToken = @{
    'Content-Type'  = 'application/json'
    'Authorization' = "Bearer " + $Token
}

#Add the current WDAC Rule to the Policy
$FilePath = "$PSScriptRoot\Policies\WDACPolicy.xml"
$PolicyFile = (get-content $FilePath -Encoding UTF8 -Raw).Tostring()
$Policy = $PolicyFile.Replace('\', '\\') -replace '\r\n','' -replace '"','\"'

#Check if Policy already exists

$IntunePolicy = (Invoke-RestMethod -Method Get -Headers $authtoken -UseBasicParsing -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies?`$select=id,name,templateReference&`$filter=templateReference/TemplateFamily eq 'endpointSecurityApplicationControl' and name eq '$PolicyName'").value
$id = $IntunePolicy.id

If ($id)
{
    write-output "Update Policy"
    $Method = "PUT"
    $URL = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies('$id')"
    $body='{"creationSource":null,"name":"' + $PolicyName + '","description":"","platforms":"windows10","technologies":"mdm","roleScopeTagIds":["0"],"settings":[{"@odata.type":"#microsoft.graph.deviceManagementConfigurationSetting","settingInstance":{"@odata.type":"#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance","settingDefinitionId":"device_vendor_msft_policy_config_applicationcontrol_policies_{policyguid}_policiesoptions","choiceSettingValue":{"@odata.type":"#microsoft.graph.deviceManagementConfigurationChoiceSettingValue","value":"device_vendor_msft_policy_config_applicationcontrol_configure_xml_selected","children":[{"@odata.type":"#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance","settingDefinitionId":"device_vendor_msft_policy_config_applicationcontrol_policies_{policyguid}_xml","simpleSettingValue":{"@odata.type":"#microsoft.graph.deviceManagementConfigurationStringSettingValue","value":"' + $Policy + '","settingValueTemplateReference":{"settingValueTemplateId":"88f6f096-dedb-4cf1-ac2f-4b41e303adb5"}},"settingInstanceTemplateReference":{"settingInstanceTemplateId":"4d709667-63d7-42f2-8e1b-b780f6c3c9c7"}}],"settingValueTemplateReference":{"settingValueTemplateId":"b28c7dc4-c7b2-4ce2-8f51-6ebfd3ea69d3"}},"settingInstanceTemplateReference":{"settingInstanceTemplateId":"1de98212-6949-42dc-a89c-e0ff6e5da04b"}}}],"templateReference":{"templateId":"4321b946-b76b-4450-8afd-769c08b16ffc_1","templateFamily":"endpointSecurityApplicationControl","templateDisplayName":"App Control for Business","templateDisplayVersion":"Version 1"}}'
    write-output $URL
    write-output $body
}
else 
{
    write-output "Create Policy"
    $Method = "POST"
    $URL = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies"
    $body='{"name":"' + $PolicyName + '","description":"","platforms":"windows10","technologies":"mdm","roleScopeTagIds":["0"],"settings":[{"@odata.type":"#microsoft.graph.deviceManagementConfigurationSetting","settingInstance":{"@odata.type":"#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance","settingDefinitionId":"device_vendor_msft_policy_config_applicationcontrol_policies_{policyguid}_policiesoptions","choiceSettingValue":{"@odata.type":"#microsoft.graph.deviceManagementConfigurationChoiceSettingValue","value":"device_vendor_msft_policy_config_applicationcontrol_configure_xml_selected","children":[{"@odata.type":"#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance","settingDefinitionId":"device_vendor_msft_policy_config_applicationcontrol_policies_{policyguid}_xml","simpleSettingValue":{"@odata.type":"#microsoft.graph.deviceManagementConfigurationStringSettingValue","value":"' + $Policy + '","settingValueTemplateReference":{"settingValueTemplateId":"88f6f096-dedb-4cf1-ac2f-4b41e303adb5"}},"settingInstanceTemplateReference":{"settingInstanceTemplateId":"4d709667-63d7-42f2-8e1b-b780f6c3c9c7"}}],"settingValueTemplateReference":{"settingValueTemplateId":"b28c7dc4-c7b2-4ce2-8f51-6ebfd3ea69d3"}},"settingInstanceTemplateReference":{"settingInstanceTemplateId":"1de98212-6949-42dc-a89c-e0ff6e5da04b"}}}],"templateReference":{"templateId":"4321b946-b76b-4450-8afd-769c08b16ffc_1"}}'
    write-output $URL
    write-output $body
}

Invoke-Restmethod -Method $Method -Headers $authtoken -body $body -Uri $URL -UseBasicParsing


