    # Connect to Intune
    $Token= [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR((Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com" -AsSecureString).Token))
           
    $script:authToken = @{
        'Content-Type'  = 'application/json'
        'Authorization' = "Bearer " + $Token
    }

    #Prepare variables and Folders for Backup

    $Path = Join-Path $PSScriptRoot -ChildPath "IntuneBackup"
        if (-not (Test-Path $Path)) {
            $null = New-Item -Path $Path -ItemType Directory
        }

    #Start Intune Backup

    ###############################################################################################################################################################

        # Create folder if not exists
        if (-not (Test-Path "$Path\App Protection Policies")) {
            $null = New-Item -Path "$Path\App Protection Policies" -ItemType Directory
        }

        # Get all App Protection Policies

        $BackupResponse = (Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/deviceAppManagement/managedAppPolicies" -Headers $authToken -Method Get)
        $appProtectionPolicies = $BackupResponse.value
        $NextLink = $BackupResponse."@odata.nextLink"
            while ($NextLink -ne $null){
                $BackupResponse = (Invoke-RestMethod -Uri $NextLink -Headers $authToken -Method Get)
                $NextLink = $BackupResponse."@odata.nextLink"
                $appProtectionPolicies += $BackupResponse.value
            }

    

        foreach ($appProtectionPolicy in $appProtectionPolicies) {
            $fileName = ($appProtectionPolicy.displayName).Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
            $appProtectionPolicy | ConvertTo-Json -Depth 100 | Out-File -LiteralPath "$path\App Protection Policies\$fileName.json"

            [PSCustomObject]@{
                "Action" = "Backup"
                "Type"   = "App Protection Policy"
                "Name"   = $appProtectionPolicy.displayName
                "Path"   = "App Protection Policies\$fileName.json"
            }
        }

    ###############################################################################################################################################################

    # Create folder if not exists
    if (-not (Test-Path "$Path\App Protection Policies\Assignments")) {
        $null = New-Item -Path "$Path\App Protection Policies\Assignments" -ItemType Directory
    }

    # Get all assignments from all policies

    foreach ($appProtectionPolicy in $appProtectionPolicies) {
        # If Android
        if ($appProtectionPolicy.'@odata.type' -eq '#microsoft.graph.androidManagedAppProtection') {
            $assignments = Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/deviceAppManagement/androidManagedAppProtections('$($appProtectionPolicy.id)')/assignments" -Headers $authToken -Method Get
        }
        # Elseif iOS
        elseif ($appProtectionPolicy.'@odata.type' -eq '#microsoft.graph.iosManagedAppProtection') {
            $assignments = Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/deviceAppManagement/iosManagedAppProtections('$($appProtectionPolicy.id)')/assignments" -Headers $authToken -Method Get
        }
        # Elseif Windows 10 with enrollment
        elseif ($appProtectionPolicy.'@odata.type' -eq '#microsoft.graph.mdmWindowsInformationProtectionPolicy') {
            $assignments = Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mdmWindowsInformationProtectionPolicies('$($appProtectionPolicy.id)')/assignments" -Headers $authToken -Method Get
        }
        # Elseif Windows 10 without enrollment
        elseif ($appProtectionPolicy.'@odata.type' -eq '#microsoft.graph.windowsInformationProtectionPolicy') {
            $assignments = Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/deviceAppManagement/windowsInformationProtectionPolicies('$($appProtectionPolicy.id)')/assignments" -Headers $authToken -Method Get
        }
        else {
            # Not supported App Protection Policy
            continue
        }

        $fileName = ($appProtectionPolicy.displayName).Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
        $assignments | ConvertTo-Json -Depth 100 | Out-File -LiteralPath "$path\App Protection Policies\Assignments\$($appProtectionPolicy.id) - $fileName.json"

        [PSCustomObject]@{
            "Action" = "Backup"
            "Type"   = "App Protection Policy Assignments"
            "Name"   = $appProtectionPolicy.displayName
            "Path"   = "App Protection Policies\Assignments\$fileName.json"
        }
    }

    ###############################################################################################################################################################

        # Create folder if not exists
        if (-not (Test-Path "$Path\Client Apps")) {
            $null = New-Item -Path "$Path\Client Apps" -ItemType Directory
        }

        # Get all Client Apps

        $BackupResponse = (Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps?$filter=(microsoft.graph.managedApp/appAvailability%20eq%20null%20or%20microsoft.graph.managedApp/appAvailability%20eq%20%27lineOfBusiness%27%20or%20isAssigned%20eq%20true)" -Headers $authToken -Method Get)
        $clientApps = $BackupResponse.value
        $NextLink = $BackupResponse."@odata.nextLink"
            while ($NextLink -ne $null){
                $BackupResponse = (Invoke-RestMethod -Uri $NextLink -Headers $authToken -Method Get)
                $NextLink = $BackupResponse."@odata.nextLink"
                $clientApps += $BackupResponse.value
            }

        foreach ($clientApp in $clientApps) {
            $clientAppType = $clientApp.'@odata.type'.split('.')[-1]

            $fileName = ($clientApp.displayName).Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
            $clientAppDetails = Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$($clientApp.id)" -Headers $authToken -Method Get
            $clientAppDetails | ConvertTo-Json | Out-File -LiteralPath "$path\Client Apps\$($clientAppType)_$($fileName).json"

            [PSCustomObject]@{
                "Action" = "Backup"
                "Type"   = "Client App"
                "Name"   = $clientApp.displayName
                "Path"   = "Client Apps\$($clientAppType)_$($fileName).json"
            }
        }

    ###############################################################################################################################################################

        # Create folder if not exists
        if (-not (Test-Path "$Path\Client Apps\Assignments")) {
            $null = New-Item -Path "$Path\Client Apps\Assignments" -ItemType Directory
        }

        foreach ($clientApp in $clientApps) {
            
            $BackupResponse = (Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$($clientApp.id)/assignments" -Headers $authToken -Method Get)
            $assignments = $BackupResponse.value
            $NextLink = $BackupResponse."@odata.nextLink"
                while ($NextLink -ne $null){
                    $BackupResponse = (Invoke-RestMethod -Uri $NextLink -Headers $authToken -Method Get)
                    $NextLink = $BackupResponse."@odata.nextLink"
                    $assignments += $BackupResponse.value
                }
            if ($assignments) {
                $fileName = ($clientApp.displayName).Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
                $assignments | ConvertTo-Json -Depth 100 | Out-File -LiteralPath "$path\Client Apps\Assignments\$($clientApp.id) - $fileName.json"

                [PSCustomObject]@{
                    "Action" = "Backup"
                    "Type"   = "Client App Assignments"
                    "Name"   = $clientApp.displayName
                    "Path"   = "Client Apps\Assignments\$fileName.json"
                }
            }
        }

    ###############################################################################################################################################################

    # Create folder if not exists
    if (-not (Test-Path "$Path\Settings Catalog")) {
        $null = New-Item -Path "$Path\Settings Catalog" -ItemType Directory
    }

    # Get all Setting Catalogs Policies
    $BackupResponse = (Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies" -Headers $authToken -Method Get)
    $configurationPolicies = $BackupResponse.value
    $NextLink = $BackupResponse."@odata.nextLink"
        while ($NextLink -ne $null){
            $BackupResponse = (Invoke-RestMethod -Uri $NextLink -Headers $authToken -Method Get)
            $NextLink = $BackupResponse."@odata.nextLink"
            $configurationPolicies += $BackupResponse.value
        }

    foreach ($configurationPolicy in $configurationPolicies) {
        $configurationPolicy | Add-Member -MemberType NoteProperty -Name 'settings' -Value @() -Force

        $BackupResponse = (Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/$($configurationPolicy.id)/settings" -Headers $authToken -Method Get)
    $settings = $BackupResponse.value
    $NextLink = $BackupResponse."@odata.nextLink"
        while ($NextLink -ne $null){
            $BackupResponse = (Invoke-RestMethod -Uri $NextLink -Headers $authToken -Method Get)
            $NextLink = $BackupResponse."@odata.nextLink"
            $settings += $BackupResponse.value
        }

        if ($settings -isnot [System.Array]) {
            $configurationPolicy.Settings = @($settings)
        } else {
            $configurationPolicy.Settings = $settings
        }
        
        $fileName = ($configurationPolicy.name).Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
        $configurationPolicy | ConvertTo-Json -Depth 100 | Out-File -LiteralPath "$path\Settings Catalog\$fileName.json"

        [PSCustomObject]@{
            "Action" = "Backup"
            "Type"   = "Settings Catalog"
            "Name"   = $configurationPolicy.name
            "Path"   = "Settings Catalog\$fileName.json"
        }
    }

    ###############################################################################################################################################################

        # Create folder if not exists
        if (-not (Test-Path "$Path\Settings Catalog\Assignments")) {
            $null = New-Item -Path "$Path\Settings Catalog\Assignments" -ItemType Directory
        }

        foreach ($configurationPolicy in $configurationPolicies) {
            $BackupResponse = (Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/$($configurationPolicy.id)/settings" -Headers $authToken -Method Get)
            $assignments = $BackupResponse.value
            $NextLink = $BackupResponse."@odata.nextLink"
                while ($NextLink -ne $null){
                    $BackupResponse = (Invoke-RestMethod -Uri $NextLink -Headers $authToken -Method Get)
                    $NextLink = $BackupResponse."@odata.nextLink"
                    $assignments += $BackupResponse.value
                }

            if ($assignments) {
                $fileName = ($configurationPolicy.name).Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
                $assignments | ConvertTo-Json | Out-File -LiteralPath "$path\Settings Catalog\Assignments\$fileName.json"

                [PSCustomObject]@{
                    "Action" = "Backup"
                    "Type"   = "Settings Catalog Assignments"
                    "Name"   = $configurationPolicy.name
                    "Path"   = "Settings Catalog\Assignments\$fileName.json"
                }
            }
        }

    ###############################################################################################################################################################

        # Create folder if not exists
        if (-not (Test-Path "$Path\Device Compliance Policies")) {
            $null = New-Item -Path "$Path\Device Compliance Policies" -ItemType Directory
        }

        # Get all Device Compliance Policies
        $BackupResponse = (Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies" -Headers $authToken -Method Get)
        $deviceCompliancePolicies = $BackupResponse.value
        $NextLink = $BackupResponse."@odata.nextLink"
            while ($NextLink -ne $null){
                $BackupResponse = (Invoke-RestMethod -Uri $NextLink -Headers $authToken -Method Get)
                $NextLink = $BackupResponse."@odata.nextLink"
                $deviceCompliancePolicies += $BackupResponse.value
            }
        
        
        foreach ($deviceCompliancePolicy in $deviceCompliancePolicies) {
            $fileName = ($deviceCompliancePolicy.displayName).Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
            $deviceCompliancePolicy | ConvertTo-Json -Depth 100 | Out-File -LiteralPath "$path\Device Compliance Policies\$fileName.json"

            [PSCustomObject]@{
                "Action" = "Backup"
                "Type"   = "Device Compliance Policy"
                "Name"   = $deviceCompliancePolicy.displayName
                "Path"   = "Device Compliance Policies\$fileName.json"
            }
        }

    ###############################################################################################################################################################

        # Create folder if not exists
        if (-not (Test-Path "$Path\Device Compliance Policies\Assignments")) {
            $null = New-Item -Path "$Path\Device Compliance Policies\Assignments" -ItemType Directory
        }

        foreach ($deviceCompliancePolicy in $deviceCompliancePolicies) {

            $BackupResponse = (Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies/$($deviceCompliancePolicy.id)/assignments" -Headers $authToken -Method Get)
            $assignments = $BackupResponse.value
            $NextLink = $BackupResponse."@odata.nextLink"
                while ($NextLink -ne $null){
                    $BackupResponse = (Invoke-RestMethod -Uri $NextLink -Headers $authToken -Method Get)
                    $NextLink = $BackupResponse."@odata.nextLink"
                    $assignments += $BackupResponse.value
                }

            if ($assignments) {
                $fileName = ($deviceCompliancePolicy.displayName).Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
                $assignments | ConvertTo-Json | Out-File -LiteralPath "$path\Device Compliance Policies\Assignments\$fileName.json"

                [PSCustomObject]@{
                    "Action" = "Backup"
                    "Type"   = "Device Compliance Policy Assignments"
                    "Name"   = $deviceCompliancePolicy.displayName
                    "Path"   = "Device Compliance Policies\Assignments\$fileName.json"
                }
            }
        }

    ###############################################################################################################################################################

        # Create folder if not exists
        if (-not (Test-Path "$Path\Device Configurations")) {
            $null = New-Item -Path "$Path\Device Configurations" -ItemType Directory
        }

        # Get all device configurations
        $BackupResponse = (Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations" -Headers $authToken -Method Get)
        $deviceConfigurations = $BackupResponse.value
        $NextLink = $BackupResponse."@odata.nextLink"
            while ($NextLink -ne $null){
                $BackupResponse = (Invoke-RestMethod -Uri $NextLink -Headers $authToken -Method Get)
                $NextLink = $BackupResponse."@odata.nextLink"
                $deviceConfigurations += $BackupResponse.value
            }
        

        foreach ($deviceConfiguration in $deviceConfigurations) {
            $fileName = ($deviceConfiguration.displayName).Split([IO.Path]::GetInvalidFileNameChars()) -join '_'

            # If it's a custom configuration, check if the device configuration contains encrypted OMA settings, then decrypt the OmaSettings to a Plain Text Value (required for import)
            if (($deviceConfiguration.'@odata.type' -eq '#microsoft.graph.windows10CustomConfiguration') -and ($deviceConfiguration.omaSettings | Where-Object { $_.isEncrypted -contains $true } )) {
                # Create an empty array for the unencrypted OMA settings.
                $newOmaSettings = @()
                foreach ($omaSetting in $deviceConfiguration.omaSettings) {
                    # Check if this particular setting is encrypted, and get the plaintext only if necessary
                    if ($omaSetting.isEncrypted) {
                        $BackupResponse = (Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations/$($deviceConfiguration.id)/getOmaSettingPlainTextValue(secretReferenceValueId='$($omaSetting.secretReferenceValueId)')" -Headers $authToken -Method Get)
                        $omaSettingValue = $BackupResponse.value
                        $NextLink = $BackupResponse."@odata.nextLink"
                            while ($NextLink -ne $null){
                                $BackupResponse = (Invoke-RestMethod -Uri $NextLink -Headers $authToken -Method Get)
                                $NextLink = $BackupResponse."@odata.nextLink"
                                $omaSettingValue += $BackupResponse.value
                            }
                    }
                    # Define a new 'unencrypted' OMA Setting
                    $newOmaSetting = @{}
                    $newOmaSetting.'@odata.type' = $omaSetting.'@odata.type'
                    $newOmaSetting.displayName = $omaSetting.displayName
                    $newOmaSetting.description = $omaSetting.description
                    $newOmaSetting.omaUri = $omaSetting.omaUri
                    $newOmaSetting.value = $omaSettingValue
                    $newOmaSetting.isEncrypted = $false
                    $newOmaSetting.secretReferenceValueId = $null

                    # Add the unencrypted OMA Setting to the Array
                    $newOmaSettings += $newOmaSetting
                }

                # Remove all encrypted OMA Settings from the Device Configuration
                $deviceConfiguration.omaSettings = @()

                # Add the unencrypted OMA Settings from the Device Configuration
                $deviceConfiguration.omaSettings += $newOmaSettings
            }

            # Export the Device Configuration Profile
            $deviceConfiguration | ConvertTo-Json -Depth 5 | Out-File -LiteralPath "$path\Device Configurations\$fileName.json"

            [PSCustomObject]@{
                "Action" = "Backup"
                "Type"   = "Device Configuration"
                "Name"   = $deviceConfiguration.displayName
                "Path"   = "Device Configurations\$fileName.json"
            }
        }

    ###############################################################################################################################################################

        # Create folder if not exists
        if (-not (Test-Path "$Path\Device Configurations\Assignments")) {
            $null = New-Item -Path "$Path\Device Configurations\Assignments" -ItemType Directory
        }

        foreach ($deviceConfiguration in $deviceConfigurations) {

            $BackupResponse = (Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations/$($deviceConfiguration.id )/assignments" -Headers $authToken -Method Get)
            $assignments = $BackupResponse.value
            $NextLink = $BackupResponse."@odata.nextLink"
                while ($NextLink -ne $null){
                    $BackupResponse = (Invoke-RestMethod -Uri $NextLink -Headers $authToken -Method Get)
                    $NextLink = $BackupResponse."@odata.nextLink"
                    $assignments += $BackupResponse.value
                }

            if ($assignments) {
                $fileName = ($deviceConfiguration.displayName).Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
                $assignments | ConvertTo-Json | Out-File -LiteralPath "$path\Device Configurations\Assignments\$fileName.json"

                [PSCustomObject]@{
                    "Action" = "Backup"
                    "Type"   = "Device Configuration Assignments"
                    "Name"   = $deviceConfiguration.displayName
                    "Path"   = "Device Configurations\Assignments\$fileName.json"
                }
            }
        }

    ###############################################################################################################################################################

        # Create folder if not exists
        if (-not (Test-Path "$Path\Device Health Scripts")) {
            $null = New-Item -Path "$Path\Device Health Scripts" -ItemType Directory
        }

        $BackupResponse = (Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts" -Headers $authToken -Method Get)
        $healthScripts = $BackupResponse.value
        $NextLink = $BackupResponse."@odata.nextLink"
            while ($NextLink -ne $null){
                $BackupResponse = (Invoke-RestMethod -Uri $NextLink -Headers $authToken -Method Get)
                $NextLink = $BackupResponse."@odata.nextLink"
                $healthScripts += $BackupResponse.value
            }


        foreach ($healthScript in $healthScripts) {
            $fileName = ($healthScript.displayName).Split([IO.Path]::GetInvalidFileNameChars()) -join '_'

            # Export the Health script profile
            $healthScript | ConvertTo-Json -Depth 100 | Out-File -LiteralPath "$path\Device Health Scripts\$fileName.json"

            # Create folder if not exists
            if (-not (Test-Path "$Path\Device Health Scripts\Script Content")) {
                $null = New-Item -Path "$Path\Device Health Scripts\Script Content" -ItemType Directory
            }

            $healthScriptObject = Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts/$($healthScript.id)" -Headers $authToken -Method Get

            $healthScriptDetectionContent = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($healthScriptObject.detectionScriptContent))
            $healthScriptDetectionContent | Out-File -LiteralPath "$path\Device Health Scripts\Script Content\$fileName`_detection.ps1"
            $healthScriptRemediationContent = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($healthScriptObject.remediationScriptContent))
            $healthScriptRemediationContent | Out-File -LiteralPath "$path\Device Health Scripts\Script Content\$fileName`_remediation.ps1"

            [PSCustomObject]@{
                "Action" = "Backup"
                "Type"   = "Device Health Scripts"
                "Name"   = $healthScript.displayName
                "Path"   = "Device Health Scripts\$fileName.json"
            }
        }

    ###############################################################################################################################################################

        # Create folder if not exists
        if (-not (Test-Path "$Path\Device Health Scripts\Assignments")) {
            $null = New-Item -Path "$Path\Device Health Scripts\Assignments" -ItemType Directory
        }

        foreach ($healthScript in $healthScripts) {
            $BackupResponse = (Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts/$($healthScript.id)/assignments" -Headers $authToken -Method Get)
            $assignments = $BackupResponse.value
            $NextLink = $BackupResponse."@odata.nextLink"
                while ($NextLink -ne $null){
                    $BackupResponse = (Invoke-RestMethod -Uri $NextLink -Headers $authToken -Method Get)
                    $NextLink = $BackupResponse."@odata.nextLink"
                    $assignments += $BackupResponse.value
                }

            if ($assignments) {
                $fileName = ($healthScript.displayName).Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
                $assignments | ConvertTo-Json | Out-File -LiteralPath "$path\Device Health Scripts\Assignments\$fileName.json"

                [PSCustomObject]@{
                    "Action" = "Backup"
                    "Type"   = "Device Health Scripts Assignments"
                    "Name"   = $healthScript.displayName
                    "Path"   = "Device Health Scripts\Assignments\$fileName.json"
                }
            }
        }

    ###############################################################################################################################################################

        # Create folder if not exists
        if (-not (Test-Path "$Path\Device Management Intents")) {
            $null = New-Item -Path "$Path\Device Management Intents" -ItemType Directory
        }

        Write-Verbose "Requesting Intents"
        $BackupResponse = (Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/deviceManagement/intents" -Headers $authToken -Method Get)
        $intents = $BackupResponse.value
        $NextLink = $BackupResponse."@odata.nextLink"
            while ($NextLink -ne $null){
                $BackupResponse = (Invoke-RestMethod -Uri $NextLink -Headers $authToken -Method Get)
                $NextLink = $BackupResponse."@odata.nextLink"
                $intents += $BackupResponse.value
            }

        foreach ($intent in $intents) {
            # Get the corresponding Device Management Template
            Write-Verbose "Requesting Template"
            $template = (Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/deviceManagement/templates/$($intent.templateId)" -Headers $authToken -Method Get)
            $templateDisplayName = ($template.displayName).Split([IO.Path]::GetInvalidFileNameChars()) -join '_'

            if (-not (Test-Path "$Path\Device Management Intents\$templateDisplayName")) {
                $null = New-Item -Path "$Path\Device Management Intents\$templateDisplayName" -ItemType Directory
            }
            
            # Get all setting categories in the Device Management Template
            Write-Verbose "Requesting Template Categories"
            $BackupResponse = (Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/deviceManagement/templates/$($intent.templateId)/categories" -Headers $authToken -Method Get)
            $templateCategories = $BackupResponse.value
            $NextLink = $BackupResponse."@odata.nextLink"
                while ($NextLink -ne $null){
                    $BackupResponse = (Invoke-RestMethod -Uri $NextLink -Headers $authToken -Method Get)
                    $NextLink = $BackupResponse."@odata.nextLink"
                    $templateCategories += $BackupResponse.value
                }
        
            $intentSettingsDelta = @()
            foreach ($templateCategory in $templateCategories) {
                # Get all configured values for the template categories
                Write-Verbose "Requesting Intent Setting Values"
                $intentSettingsDelta += (Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/deviceManagement/intents/$($intent.id)/categories/$($templateCategory.id)/settings" -Headers $authToken -Method Get).value
            }

            $intentBackupValue = @{
                "displayName" = $intent.displayName
                "description" = $intent.description
                "settingsDelta" = $intentSettingsDelta
                "roleScopeTagIds" = $intent.roleScopeTagIds
            }
            
            $fileName = ("$($template.id)_$($intent.displayName)").Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
            $intentBackupValue | ConvertTo-Json | Out-File -LiteralPath "$path\Device Management Intents\$templateDisplayName\$fileName.json"

            [PSCustomObject]@{
                "Action" = "Backup"
                "Type"   = "Device Management Intent"
                "Name"   = $intent.displayName
                "Path"   = "Device Management Intents\$templateDisplayName\$fileName.json"
            }
        }

    ###############################################################################################################################################################

        # Create folder if not exists
        if (-not (Test-Path "$Path\Device Management Scripts\Script Content")) {
            $null = New-Item -Path "$Path\Device Management Scripts\Script Content" -ItemType Directory
        }

        # Get all device management scripts
        $BackupResponse = (Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts" -Headers $authToken -Method Get)
        $deviceManagementScripts = $BackupResponse.value
        $NextLink = $BackupResponse."@odata.nextLink"
            while ($NextLink -ne $null){
                $BackupResponse = (Invoke-RestMethod -Uri $NextLink -Headers $authToken -Method Get)
                $NextLink = $BackupResponse."@odata.nextLink"
                $deviceManagementScripts += $BackupResponse.value
            }

        foreach ($deviceManagementScript in $deviceManagementScripts) {
            # ScriptContent returns null, so we have to query Microsoft Graph for each script
            $deviceManagementScriptObject = (Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts/$($deviceManagementScript.Id)" -Headers $authToken -Method Get)
            $deviceManagementScriptFileName = ($deviceManagementScriptObject.displayName).Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
            $deviceManagementScriptObject | ConvertTo-Json | Out-File -LiteralPath "$path\Device Management Scripts\$deviceManagementScriptFileName.json"

            $deviceManagementScriptContent = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($deviceManagementScriptObject.scriptContent))
            $deviceManagementScriptContent | Out-File -LiteralPath "$path\Device Management Scripts\Script Content\$deviceManagementScriptFileName.ps1"

            [PSCustomObject]@{
                "Action" = "Backup"
                "Type"   = "Device Management Script"
                "Name"   = $deviceManagementScript.displayName
                "Path"   = "Device Management Scripts\$deviceManagementScriptFileName.json"
            }
        }

    ###############################################################################################################################################################

        # Create folder if not exists
        if (-not (Test-Path "$Path\Device Management Scripts\Assignments")) {
            $null = New-Item -Path "$Path\Device Management Scripts\Assignments" -ItemType Directory
        }

        foreach ($deviceManagementScript in $deviceManagementScripts) {
            $BackupResponse = (Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts/$($deviceManagementScript.id)/assignments" -Headers $authToken -Method Get)
            $assignments = $BackupResponse.value
            $NextLink = $BackupResponse."@odata.nextLink"
                while ($NextLink -ne $null){
                    $BackupResponse = (Invoke-RestMethod -Uri $NextLink -Headers $authToken -Method Get)
                    $NextLink = $BackupResponse."@odata.nextLink"
                    $assignments += $BackupResponse.value
                }

            if ($assignments) {
                $fileName = ($deviceManagementScript.displayName).Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
                $assignments | ConvertTo-Json | Out-File -LiteralPath "$path\Device Management Scripts\Assignments\$fileName.json"

                [PSCustomObject]@{
                    "Action" = "Backup"
                    "Type"   = "Device Management Script Assignments"
                    "Name"   = $deviceManagementScript.displayName
                    "Path"   = "Device Management Scripts\Assignments\$fileName.json"
                }
            }
        }

    ###############################################################################################################################################################

        # Create folder if not exists
        if (-not (Test-Path "$Path\Administrative Templates")) {
            $null = New-Item -Path "$Path\Administrative Templates" -ItemType Directory
        }

        # Get all Group Policy Configurations

        $BackupResponse = (Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations" -Headers $authToken -Method Get)
        $groupPolicyConfigurations = $BackupResponse.value
        $NextLink = $BackupResponse."@odata.nextLink"
            while ($NextLink -ne $null){
                $BackupResponse = (Invoke-RestMethod -Uri $NextLink -Headers $authToken -Method Get)
                $NextLink = $BackupResponse."@odata.nextLink"
                $groupPolicyConfigurations += $BackupResponse.value
            }


        foreach ($groupPolicyConfiguration in $groupPolicyConfigurations) {
            $BackupResponse = (Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations/$($groupPolicyConfiguration.id)/definitionValues" -Headers $authToken -Method Get)
            $groupPolicyDefinitionValues = $BackupResponse.value
            $NextLink = $BackupResponse."@odata.nextLink"
                while ($NextLink -ne $null){
                    $BackupResponse = (Invoke-RestMethod -Uri $NextLink -Headers $authToken -Method Get)
                    $NextLink = $BackupResponse."@odata.nextLink"
                    $groupPolicyDefinitionValues += $BackupResponse.value
                }
            $groupPolicyBackupValues = @()

            foreach ($groupPolicyDefinitionValue in $groupPolicyDefinitionValues) {
                $groupPolicyDefinition = (Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations/$($groupPolicyConfiguration.id)/definitionValues/$($groupPolicyDefinitionValue.id)/definition" -Headers $authToken -Method Get)
                $groupPolicyPresentationValues = (Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations/$($groupPolicyConfiguration.id)/definitionValues/$($groupPolicyDefinitionValue.id)/presentationValues?`$expand=presentation" -Headers $authToken -Method Get).Value | Select-Object -Property * -ExcludeProperty lastModifiedDateTime, createdDateTime
                $groupPolicyBackupValue = @{
                    "enabled" = $groupPolicyDefinitionValue.enabled
                    "definition@odata.bind" = "https://graph.microsoft.com/beta/deviceManagement/groupPolicyDefinitions('$($groupPolicyDefinition.id)')"
                }

                if ($groupPolicyPresentationValues.value) {
                    $groupPolicyBackupValue."presentationValues" = @()
                    foreach ($groupPolicyPresentationValue in $groupPolicyPresentationValues) {
                        $groupPolicyBackupValue."presentationValues" +=
                            @{
                                "@odata.type" = $groupPolicyPresentationValue.'@odata.type'
                                "value" = $groupPolicyPresentationValue.value
                                "presentation@odata.bind" = "https://graph.microsoft.com/beta/deviceManagement/groupPolicyDefinitions('$($groupPolicyDefinition.id)')/presentations('$($groupPolicyPresentationValue.presentation.id)')"
                            }
                    }
                } elseif ($groupPolicyPresentationValues.values) {
                    $groupPolicyBackupValue."presentationValues" = @(
                        @{
                            "@odata.type" = $groupPolicyPresentationValues.'@odata.type'
                            "values" = @(
                                foreach ($groupPolicyPresentationValue in $groupPolicyPresentationValues.values) {
                                    @{
                                        "name" = $groupPolicyPresentationValue.name
                                        "value" = $groupPolicyPresentationValue.value
                                    }
                                }
                            )
                            "presentation@odata.bind" = "https://graph.microsoft.com/beta/deviceManagement/groupPolicyDefinitions('$($groupPolicyDefinition.id)')/presentations('$($groupPolicyPresentationValues.presentation.id)')"
                        }
                    )
                }

                $groupPolicyBackupValues += $groupPolicyBackupValue
            }

            $fileName = ($groupPolicyConfiguration.displayName).Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
            $groupPolicyBackupValues | ConvertTo-Json -Depth 100 | Out-File -LiteralPath "$path\Administrative Templates\$fileName.json"

            [PSCustomObject]@{
                "Action" = "Backup"
                "Type"   = "Administrative Template"
                "Name"   = $groupPolicyConfiguration.displayName
                "Path"   = "Administrative Templates\$fileName.json"
            }
        }

    ###############################################################################################################################################################

        # Create folder if not exists
        if (-not (Test-Path "$Path\Administrative Templates\Assignments")) {
            $null = New-Item -Path "$Path\Administrative Templates\Assignments" -ItemType Directory
        }

        foreach ($groupPolicyConfiguration in $groupPolicyConfigurations) {
            $BackupResponse = (Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations/$($groupPolicyConfiguration.id)/assignments" -Headers $authToken -Method Get)
            $assignments = $BackupResponse.value
            $NextLink = $BackupResponse."@odata.nextLink"
                while ($NextLink -ne $null){
                    $BackupResponse = (Invoke-RestMethod -Uri $NextLink -Headers $authToken -Method Get)
                    $NextLink = $BackupResponse."@odata.nextLink"
                    $assignments += $BackupResponse.value
                }
        

            if ($assignments) {
                $fileName = ($groupPolicyConfiguration.displayName).Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
                $assignments | ConvertTo-Json | Out-File -LiteralPath "$path\Administrative Templates\Assignments\$fileName.json"

                [PSCustomObject]@{
                    "Action" = "Backup"
                    "Type"   = "Administrative Template Assignments"
                    "Name"   = $groupPolicyConfiguration.displayName
                    "Path"   = "Administrative Templates\Assignments\$fileName.json"
                }
            }
        }

    ###############################################################################################################################################################
