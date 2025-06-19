    # Connect to Intune
    $Token= [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR((Get-AzAccessToken -TenantId "<INSERT Tenand ID HERE>" -ResourceUrl "https://graph.microsoft.com" -AsSecureString).Token))
    Connect-MgGraph -AccessToken $Token

    
    #Prepare variables and Folders for Backup

    $Path = Join-Path $PSScriptRoot -ChildPath "IntuneBackup"
        if (-not (Test-Path $Path)) 
        {
            $null = New-Item -Path $Path -ItemType Directory
        }
        else
        {
            remove-item $path -Recurse
            $null = New-Item -Path $Path -ItemType Directory
        }

    #Start Intune Backup

    ###############################################################################################################################################################
    #region App Protection Policies
    write-output Region App Protection Policies
        # Create folder if not exists
        if (-not (Test-Path "$Path\App Protection Policies")) {
            $null = New-Item -Path "$Path\App Protection Policies" -ItemType Directory
        }

        # Get all App Protection Policies

        $BackupResponse = (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceAppManagement/managedAppPolicies" -Method Get)
        $appProtectionPolicies = $BackupResponse.value
        $NextLink = $BackupResponse."@odata.nextLink"
            while ($null -ne $NextLink){
                $BackupResponse = (Invoke-MgGraphRequest -Uri $NextLink -Method Get)
                $NextLink = $BackupResponse."@odata.nextLink"
                $appProtectionPolicies += $BackupResponse.value
            }

    

        foreach ($appProtectionPolicy in $appProtectionPolicies) {
            $fileName = ($appProtectionPolicy.displayName).Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
            $appProtectionPolicy | ConvertTo-Json -Depth 100 | Out-File -Encoding utf8 -LiteralPath "$path\App Protection Policies\$fileName.json"

            [PSCustomObject]@{
                "Action" = "Backup"
                "Type"   = "App Protection Policy"
                "Name"   = $appProtectionPolicy.displayName
                "Path"   = "App Protection Policies\$fileName.json"
            }
        }

    ###############################################################################################################################################################
    #region App Protection Policies Assignments
    write-output Region App Protection Policies Assignments
    # Create folder if not exists
    if (-not (Test-Path "$Path\App Protection Policies\Assignments")) {
        $null = New-Item -Path "$Path\App Protection Policies\Assignments" -ItemType Directory
    }

    # Get all assignments from all policies

    foreach ($appProtectionPolicy in $appProtectionPolicies) {
        # If Android
        if ($appProtectionPolicy.'@odata.type' -eq '#microsoft.graph.androidManagedAppProtection') {
            $assignments = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceAppManagement/androidManagedAppProtections('$($appProtectionPolicy.id)')/assignments" -Method Get
        }
        # Elseif iOS
        elseif ($appProtectionPolicy.'@odata.type' -eq '#microsoft.graph.iosManagedAppProtection') {
            $assignments = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceAppManagement/iosManagedAppProtections('$($appProtectionPolicy.id)')/assignments" -Method Get
        }
        # Elseif Windows 10 with enrollment
        elseif ($appProtectionPolicy.'@odata.type' -eq '#microsoft.graph.mdmWindowsInformationProtectionPolicy') {
            $assignments = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mdmWindowsInformationProtectionPolicies('$($appProtectionPolicy.id)')/assignments" -Method Get
        }
        # Elseif Windows 10 without enrollment
        elseif ($appProtectionPolicy.'@odata.type' -eq '#microsoft.graph.windowsInformationProtectionPolicy') {
            $assignments = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceAppManagement/windowsInformationProtectionPolicies('$($appProtectionPolicy.id)')/assignments" -Method Get
        }
        else {
            # Not supported App Protection Policy
            continue
        }

        $fileName = ($appProtectionPolicy.displayName).Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
        $assignments | ConvertTo-Json -Depth 100 | Out-File -Encoding utf8 -LiteralPath "$path\App Protection Policies\Assignments\$($appProtectionPolicy.id) - $fileName.json"

        [PSCustomObject]@{
            "Action" = "Backup"
            "Type"   = "App Protection Policy Assignments"
            "Name"   = $appProtectionPolicy.displayName
            "Path"   = "App Protection Policies\Assignments\$fileName.json"
        }
    }

    ###############################################################################################################################################################
    #region App Configuration Policies
    write-output Region App Configuration Policies
        # Create folder if not exists
        if (-not (Test-Path "$Path\App Configuration Policies")) {
            $null = New-Item -Path "$Path\App Configuration Policies" -ItemType Directory
        }

        # Get all App Configuration Policies

        $BackupResponse = (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileAppConfigurations" -Method Get)
        $appConfigurationPolicies = $BackupResponse.value
        $NextLink = $BackupResponse."@odata.nextLink"
            while ($null -ne $NextLink){
                $BackupResponse = (Invoke-MgGraphRequest -Uri $NextLink -Method Get)
                $NextLink = $BackupResponse."@odata.nextLink"
                $appConfigurationPolicies += $BackupResponse.value
            }

    

        foreach ($appConfigurationPolicy in $appConfigurationPolicies) {
            $fileName = ($appConfigurationPolicy.displayName).Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
            $appConfigurationPolicy | ConvertTo-Json -Depth 100 | Out-File -Encoding utf8 -LiteralPath "$path\App Configuration Policies\$fileName.json"

            [PSCustomObject]@{
                "Action" = "Backup"
                "Type"   = "App Configuration Policy"
                "Name"   = $appConfigurationPolicy.displayName
                "Path"   = "App Configuration Policies\$fileName.json"
            }
        }

    ###############################################################################################################################################################
    #region App Configuration Policies Assignments
    write-output Region App Configuration Policies Assignments
    # Create folder if not exists
    if (-not (Test-Path "$Path\App Configuration Policies\Assignments")) {
        $null = New-Item -Path "$Path\App Configuration Policies\Assignments" -ItemType Directory
    }

    # Get all assignments from all policies

    foreach ($appConfigurationPolicy in $appConfigurationPolicies) {

            $assignments = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileAppConfigurations('$($appConfigurationPolicy.id)')/assignments" -Method Get

        $fileName = ($appConfigurationPolicy.displayName).Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
        $assignments | ConvertTo-Json -Depth 100 | Out-File -Encoding utf8 -LiteralPath "$path\App Configuration Policies\Assignments\$($appConfigurationPolicy.id) - $fileName.json"

        [PSCustomObject]@{
            "Action" = "Backup"
            "Type"   = "App Configuration Policy Assignments"
            "Name"   = $appConfigurationPolicy.displayName
            "Path"   = "App Configuration Policies\Assignments\$fileName.json"
        }
    }

    ###############################################################################################################################################################
    #region Settings Catalog
    write-output Region Settings Catalog
    # Create folder if not exists
    if (-not (Test-Path "$Path\Settings Catalog")) {
        $null = New-Item -Path "$Path\Settings Catalog" -ItemType Directory
    }

    # Get all Setting Catalogs Policies
    $BackupResponse = (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies" -Method Get)
    $configurationPolicies = $BackupResponse.value
    $NextLink = $BackupResponse."@odata.nextLink"
        while ($null -ne $NextLink){
            $BackupResponse = (Invoke-MgGraphRequest -Uri $NextLink -Method Get)
            $NextLink = $BackupResponse."@odata.nextLink"
            $configurationPolicies += $BackupResponse.value
        }

    foreach ($configurationPolicy in $configurationPolicies) {
        $configurationPolicy | Add-Member -MemberType NoteProperty -Name 'settings' -Value @() -Force

        $BackupResponse = (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/$($configurationPolicy.id)/settings" -Method Get)
    $settings = $BackupResponse.value
    $NextLink = $BackupResponse."@odata.nextLink"
        while ($null -ne $NextLink){
            $BackupResponse = (Invoke-MgGraphRequest -Uri $NextLink -Method Get)
            $NextLink = $BackupResponse."@odata.nextLink"
            $settings += $BackupResponse.value
        }

        if ($settings -isnot [System.Array]) {
            $configurationPolicy.Settings = @($settings)
        } else {
            $configurationPolicy.Settings = $settings
        }
        
        $fileName = ($configurationPolicy.name).Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
        $configurationPolicy | ConvertTo-Json -Depth 100 | Out-File -Encoding utf8 -LiteralPath "$path\Settings Catalog\$fileName.json"

        [PSCustomObject]@{
            "Action" = "Backup"
            "Type"   = "Settings Catalog"
            "Name"   = $configurationPolicy.name
            "Path"   = "Settings Catalog\$fileName.json"
        }
    }

    ###############################################################################################################################################################
    #region Settings Catalog Assignments
    write-output Region Settings Catalog Assignments
        # Create folder if not exists
        if (-not (Test-Path "$Path\Settings Catalog\Assignments")) {
            $null = New-Item -Path "$Path\Settings Catalog\Assignments" -ItemType Directory
        }

        foreach ($configurationPolicy in $configurationPolicies) {
            $BackupResponse = (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/$($configurationPolicy.id)/settings" -Method Get)
            $assignments = $BackupResponse.value
            $NextLink = $BackupResponse."@odata.nextLink"
                while ($null -ne $NextLink){
                    $BackupResponse = (Invoke-MgGraphRequest -Uri $NextLink -Method Get)
                    $NextLink = $BackupResponse."@odata.nextLink"
                    $assignments += $BackupResponse.value
                }

            if ($assignments) {
                $fileName = ($configurationPolicy.name).Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
                $assignments | ConvertTo-Json  | Out-File -Encoding utf8 -LiteralPath "$path\Settings Catalog\Assignments\$fileName.json"

                [PSCustomObject]@{
                    "Action" = "Backup"
                    "Type"   = "Settings Catalog Assignments"
                    "Name"   = $configurationPolicy.name
                    "Path"   = "Settings Catalog\Assignments\$fileName.json"
                }
            }
        }

    ###############################################################################################################################################################
    #region Device Compliance Policies
    write-output Region Device Compliance Policies
        # Create folder if not exists
        if (-not (Test-Path "$Path\Device Compliance Policies")) {
            $null = New-Item -Path "$Path\Device Compliance Policies" -ItemType Directory
        }

        # Get all Device Compliance Policies
        $BackupResponse = (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies" -Method Get)
        $deviceCompliancePolicies = $BackupResponse.value
        $NextLink = $BackupResponse."@odata.nextLink"
            while ($null -ne $NextLink){
                $BackupResponse = (Invoke-MgGraphRequest -Uri $NextLink -Method Get)
                $NextLink = $BackupResponse."@odata.nextLink"
                $deviceCompliancePolicies += $BackupResponse.value
            }
        
        
        foreach ($deviceCompliancePolicy in $deviceCompliancePolicies) {
            $fileName = ($deviceCompliancePolicy.displayName).Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
            $deviceCompliancePolicy | ConvertTo-Json -Depth 100 | Out-File -Encoding utf8 -LiteralPath "$path\Device Compliance Policies\$fileName.json"

            [PSCustomObject]@{
                "Action" = "Backup"
                "Type"   = "Device Compliance Policy"
                "Name"   = $deviceCompliancePolicy.displayName
                "Path"   = "Device Compliance Policies\$fileName.json"
            }
        }

    ###############################################################################################################################################################
    #region Device Compliance Policies Assignments
    write-output Region Device Compliance Policies Assignments
        # Create folder if not exists
        if (-not (Test-Path "$Path\Device Compliance Policies\Assignments")) {
            $null = New-Item -Path "$Path\Device Compliance Policies\Assignments" -ItemType Directory
        }

        foreach ($deviceCompliancePolicy in $deviceCompliancePolicies) {

            $BackupResponse = (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies/$($deviceCompliancePolicy.id)/assignments" -Method Get)
            $assignments = $BackupResponse.value
            $NextLink = $BackupResponse."@odata.nextLink"
                while ($null -ne $NextLink){
                    $BackupResponse = (Invoke-MgGraphRequest -Uri $NextLink -Method Get)
                    $NextLink = $BackupResponse."@odata.nextLink"
                    $assignments += $BackupResponse.value
                }

            if ($assignments) {
                $fileName = ($deviceCompliancePolicy.displayName).Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
                $assignments | ConvertTo-Json  | Out-File -Encoding utf8 -LiteralPath "$path\Device Compliance Policies\Assignments\$fileName.json"

                [PSCustomObject]@{
                    "Action" = "Backup"
                    "Type"   = "Device Compliance Policy Assignments"
                    "Name"   = $deviceCompliancePolicy.displayName
                    "Path"   = "Device Compliance Policies\Assignments\$fileName.json"
                }
            }
        }

    ###############################################################################################################################################################
    #region Device Configurations
    write-output Region Device Configurations
        # Create folder if not exists
        if (-not (Test-Path "$Path\Device Configurations")) {
            $null = New-Item -Path "$Path\Device Configurations" -ItemType Directory
        }

        # Get all device configurations
        $BackupResponse = (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations" -Method Get)
        $deviceConfigurations = $BackupResponse.value
        $NextLink = $BackupResponse."@odata.nextLink"
            while ($null -ne $NextLink){
                $BackupResponse = (Invoke-MgGraphRequest -Uri $NextLink -Method Get)
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
                        $BackupResponse = (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations/$($deviceConfiguration.id)/getOmaSettingPlainTextValue(secretReferenceValueId='$($omaSetting.secretReferenceValueId)')" -Method Get)
                        $omaSettingValue = $BackupResponse.value
                        $NextLink = $BackupResponse."@odata.nextLink"
                            while ($null -ne $NextLink){
                                $BackupResponse = (Invoke-MgGraphRequest -Uri $NextLink -Method Get)
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
            $deviceConfiguration | ConvertTo-Json -Depth 5 | Out-File -Encoding utf8 -LiteralPath "$path\Device Configurations\$fileName.json"

            [PSCustomObject]@{
                "Action" = "Backup"
                "Type"   = "Device Configuration"
                "Name"   = $deviceConfiguration.displayName
                "Path"   = "Device Configurations\$fileName.json"
            }
        }

    ###############################################################################################################################################################
    #region Device Configurations Assignments
    write-output Region Device Configurations Assignments
        # Create folder if not exists
        if (-not (Test-Path "$Path\Device Configurations\Assignments")) {
            $null = New-Item -Path "$Path\Device Configurations\Assignments" -ItemType Directory
        }

        foreach ($deviceConfiguration in $deviceConfigurations) {

            $BackupResponse = (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations/$($deviceConfiguration.id )/assignments" -Method Get)
            $assignments = $BackupResponse.value
            $NextLink = $BackupResponse."@odata.nextLink"
                while ($null -ne $NextLink){
                    $BackupResponse = (Invoke-MgGraphRequest -Uri $NextLink -Method Get)
                    $NextLink = $BackupResponse."@odata.nextLink"
                    $assignments += $BackupResponse.value
                }

            if ($assignments) {
                $fileName = ($deviceConfiguration.displayName).Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
                $assignments | ConvertTo-Json  | Out-File -Encoding utf8 -LiteralPath "$path\Device Configurations\Assignments\$fileName.json"

                [PSCustomObject]@{
                    "Action" = "Backup"
                    "Type"   = "Device Configuration Assignments"
                    "Name"   = $deviceConfiguration.displayName
                    "Path"   = "Device Configurations\Assignments\$fileName.json"
                }
            }
        }

    ###############################################################################################################################################################
    #region Device Health Scripts
    write-output Region Device Health Scripts
        # Create folder if not exists
        if (-not (Test-Path "$Path\Device Health Scripts")) {
            $null = New-Item -Path "$Path\Device Health Scripts" -ItemType Directory
        }

        $BackupResponse = (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts" -Method Get)
        $healthScripts = $BackupResponse.value
        $NextLink = $BackupResponse."@odata.nextLink"
            while ($null -ne $NextLink){
                $BackupResponse = (Invoke-MgGraphRequest -Uri $NextLink -Method Get)
                $NextLink = $BackupResponse."@odata.nextLink"
                $healthScripts += $BackupResponse.value
            }


        foreach ($healthScript in $healthScripts) {
            $fileName = ($healthScript.displayName).Split([IO.Path]::GetInvalidFileNameChars()) -join '_'

            # Export the Health script profile
            $healthScript | ConvertTo-Json -Depth 100 | Out-File -Encoding utf8 -LiteralPath "$path\Device Health Scripts\$fileName.json"

            # Create folder if not exists
            if (-not (Test-Path "$Path\Device Health Scripts\Script Content")) {
                $null = New-Item -Path "$Path\Device Health Scripts\Script Content" -ItemType Directory
            }

            $healthScriptObject = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts/$($healthScript.id)" -Method Get

            $healthScriptDetectionContent = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($healthScriptObject.detectionScriptContent))
            $healthScriptDetectionContent | Out-File -Encoding utf8 -LiteralPath "$path\Device Health Scripts\Script Content\$fileName`_detection.ps1"
            $healthScriptRemediationContent = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($healthScriptObject.remediationScriptContent))
            $healthScriptRemediationContent | Out-File -Encoding utf8 -LiteralPath "$path\Device Health Scripts\Script Content\$fileName`_remediation.ps1"

            [PSCustomObject]@{
                "Action" = "Backup"
                "Type"   = "Device Health Scripts"
                "Name"   = $healthScript.displayName
                "Path"   = "Device Health Scripts\$fileName.json"
            }
        }

    ###############################################################################################################################################################
    #region Device Health Scripts Assignments
    write-output Region Device Health Scripts Assignments
        # Create folder if not exists
        if (-not (Test-Path "$Path\Device Health Scripts\Assignments")) {
            $null = New-Item -Path "$Path\Device Health Scripts\Assignments" -ItemType Directory
        }

        foreach ($healthScript in $healthScripts) {
            $BackupResponse = (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts/$($healthScript.id)/assignments" -Method Get)
            $assignments = $BackupResponse.value
            $NextLink = $BackupResponse."@odata.nextLink"
                while ($null -ne $NextLink){
                    $BackupResponse = (Invoke-MgGraphRequest -Uri $NextLink -Method Get)
                    $NextLink = $BackupResponse."@odata.nextLink"
                    $assignments += $BackupResponse.value
                }

            if ($assignments) {
                $fileName = ($healthScript.displayName).Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
                $assignments | ConvertTo-Json  | Out-File -Encoding utf8 -LiteralPath "$path\Device Health Scripts\Assignments\$fileName.json"

                [PSCustomObject]@{
                    "Action" = "Backup"
                    "Type"   = "Device Health Scripts Assignments"
                    "Name"   = $healthScript.displayName
                    "Path"   = "Device Health Scripts\Assignments\$fileName.json"
                }
            }
        }

    ###############################################################################################################################################################
    #region Device Management Intents
    write-output Region Device Management Intents
        # Create folder if not exists
        if (-not (Test-Path "$Path\Device Management Intents")) {
            $null = New-Item -Path "$Path\Device Management Intents" -ItemType Directory
        }

        Write-Verbose "Requesting Intents"
        $BackupResponse = (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/intents" -Method Get)
        $intents = $BackupResponse.value
        $NextLink = $BackupResponse."@odata.nextLink"
            while ($null -ne $NextLink){
                $BackupResponse = (Invoke-MgGraphRequest -Uri $NextLink -Method Get)
                $NextLink = $BackupResponse."@odata.nextLink"
                $intents += $BackupResponse.value
            }

        foreach ($intent in $intents) {
            # Get the corresponding Device Management Template
            Write-Verbose "Requesting Template"
            $template = (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/templates/$($intent.templateId)" -Method Get)
            $templateDisplayName = ($template.displayName).Split([IO.Path]::GetInvalidFileNameChars()) -join '_'

            if (-not (Test-Path "$Path\Device Management Intents\$templateDisplayName")) {
                $null = New-Item -Path "$Path\Device Management Intents\$templateDisplayName" -ItemType Directory
            }
            
            # Get all setting categories in the Device Management Template
            Write-Verbose "Requesting Template Categories"
            $BackupResponse = (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/templates/$($intent.templateId)/categories" -Method Get)
            $templateCategories = $BackupResponse.value
            $NextLink = $BackupResponse."@odata.nextLink"
                while ($null -ne $NextLink){
                    $BackupResponse = (Invoke-MgGraphRequest -Uri $NextLink -Method Get)
                    $NextLink = $BackupResponse."@odata.nextLink"
                    $templateCategories += $BackupResponse.value
                }
        
            $intentSettingsDelta = @()
            foreach ($templateCategory in $templateCategories) {
                # Get all configured values for the template categories
                Write-Verbose "Requesting Intent Setting Values"
                $intentSettingsDelta += (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/intents/$($intent.id)/categories/$($templateCategory.id)/settings" -Method Get).value
            }

            $intentBackupValue = @{
                "displayName" = $intent.displayName
                "description" = $intent.description
                "settingsDelta" = $intentSettingsDelta
                "roleScopeTagIds" = $intent.roleScopeTagIds
            }
            
            $fileName = ("$($template.id)_$($intent.displayName)").Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
            $intentBackupValue | ConvertTo-Json  | Out-File -Encoding utf8 -LiteralPath "$path\Device Management Intents\$templateDisplayName\$fileName.json"

            [PSCustomObject]@{
                "Action" = "Backup"
                "Type"   = "Device Management Intent"
                "Name"   = $intent.displayName
                "Path"   = "Device Management Intents\$templateDisplayName\$fileName.json"
            }
        }

    ###############################################################################################################################################################
    #region Device Management Scripts Content
    write-output Region Device Management Scripts Content
        # Create folder if not exists
        if (-not (Test-Path "$Path\Device Management Scripts\Script Content")) {
            $null = New-Item -Path "$Path\Device Management Scripts\Script Content" -ItemType Directory
        }

        # Get all device management scripts
        $BackupResponse = (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts" -Method Get)
        $deviceManagementScripts = $BackupResponse.value
        $NextLink = $BackupResponse."@odata.nextLink"
            while ($null -ne $NextLink){
                $BackupResponse = (Invoke-MgGraphRequest -Uri $NextLink -Method Get)
                $NextLink = $BackupResponse."@odata.nextLink"
                $deviceManagementScripts += $BackupResponse.value
            }

        foreach ($deviceManagementScript in $deviceManagementScripts) {
            # ScriptContent returns null, so we have to query Microsoft Graph for each script
            $deviceManagementScriptObject = (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts/$($deviceManagementScript.Id)" -Method Get)
            $deviceManagementScriptFileName = ($deviceManagementScriptObject.displayName).Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
            $deviceManagementScriptObject | ConvertTo-Json  | Out-File -Encoding utf8 -LiteralPath "$path\Device Management Scripts\$deviceManagementScriptFileName.json"

            $deviceManagementScriptContent = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($deviceManagementScriptObject.scriptContent))
            $deviceManagementScriptContent | Out-File -Encoding utf8 -LiteralPath "$path\Device Management Scripts\Script Content\$deviceManagementScriptFileName.ps1"

            [PSCustomObject]@{
                "Action" = "Backup"
                "Type"   = "Device Management Script"
                "Name"   = $deviceManagementScript.displayName
                "Path"   = "Device Management Scripts\$deviceManagementScriptFileName.json"
            }
        }

    ###############################################################################################################################################################
    #region Device Management Scripts Assignments
    write-output Region Device Management Scripts Assignments
        # Create folder if not exists
        if (-not (Test-Path "$Path\Device Management Scripts\Assignments")) {
            $null = New-Item -Path "$Path\Device Management Scripts\Assignments" -ItemType Directory
        }

        foreach ($deviceManagementScript in $deviceManagementScripts) {
            $BackupResponse = (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts/$($deviceManagementScript.id)/assignments" -Method Get)
            $assignments = $BackupResponse.value
            $NextLink = $BackupResponse."@odata.nextLink"
                while ($null -ne $NextLink){
                    $BackupResponse = (Invoke-MgGraphRequest -Uri $NextLink -Method Get)
                    $NextLink = $BackupResponse."@odata.nextLink"
                    $assignments += $BackupResponse.value
                }

            if ($assignments) {
                $fileName = ($deviceManagementScript.displayName).Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
                $assignments | ConvertTo-Json  | Out-File -Encoding utf8 -LiteralPath "$path\Device Management Scripts\Assignments\$fileName.json"

                [PSCustomObject]@{
                    "Action" = "Backup"
                    "Type"   = "Device Management Script Assignments"
                    "Name"   = $deviceManagementScript.displayName
                    "Path"   = "Device Management Scripts\Assignments\$fileName.json"
                }
            }
        }

    ###############################################################################################################################################################
    #region Administrative Templates
    write-output Region Administrative Templates
        # Create folder if not exists
        if (-not (Test-Path "$Path\Administrative Templates")) {
            $null = New-Item -Path "$Path\Administrative Templates" -ItemType Directory
        }

        # Get all Group Policy Configurations

        $BackupResponse = (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations" -Method Get)
        $groupPolicyConfigurations = $BackupResponse.value
        $NextLink = $BackupResponse."@odata.nextLink"
            while ($null -ne $NextLink){
                $BackupResponse = (Invoke-MgGraphRequest -Uri $NextLink -Method Get)
                $NextLink = $BackupResponse."@odata.nextLink"
                $groupPolicyConfigurations += $BackupResponse.value
            }


        foreach ($groupPolicyConfiguration in $groupPolicyConfigurations) {
            $BackupResponse = (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations/$($groupPolicyConfiguration.id)/definitionValues" -Method Get)
            $groupPolicyDefinitionValues = $BackupResponse.value
            $NextLink = $BackupResponse."@odata.nextLink"
                while ($null -ne $NextLink){
                    $BackupResponse = (Invoke-MgGraphRequest -Uri $NextLink -Method Get)
                    $NextLink = $BackupResponse."@odata.nextLink"
                    $groupPolicyDefinitionValues += $BackupResponse.value
                }
            $groupPolicyBackupValues = @()

            foreach ($groupPolicyDefinitionValue in $groupPolicyDefinitionValues) {
                $groupPolicyDefinition = (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations/$($groupPolicyConfiguration.id)/definitionValues/$($groupPolicyDefinitionValue.id)/definition" -Method Get)
                $groupPolicyPresentationValues = (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations/$($groupPolicyConfiguration.id)/definitionValues/$($groupPolicyDefinitionValue.id)/presentationValues?`$expand=presentation" -Method Get).Value | Select-Object -Property * -ExcludeProperty lastModifiedDateTime, createdDateTime
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
            $groupPolicyBackupValues | ConvertTo-Json -Depth 100 | Out-File -Encoding utf8 -LiteralPath "$path\Administrative Templates\$fileName.json"

            [PSCustomObject]@{
                "Action" = "Backup"
                "Type"   = "Administrative Template"
                "Name"   = $groupPolicyConfiguration.displayName
                "Path"   = "Administrative Templates\$fileName.json"
            }
        }

    ###############################################################################################################################################################
    #region Administrative Templates Assignments
    write-output Region Administrative Templates Assignments
        # Create folder if not exists
        if (-not (Test-Path "$Path\Administrative Templates\Assignments")) {
            $null = New-Item -Path "$Path\Administrative Templates\Assignments" -ItemType Directory
        }

        foreach ($groupPolicyConfiguration in $groupPolicyConfigurations) {
            $BackupResponse = (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations/$($groupPolicyConfiguration.id)/assignments" -Method Get)
            $assignments = $BackupResponse.value
            $NextLink = $BackupResponse."@odata.nextLink"
                while ($null -ne $NextLink){
                    $BackupResponse = (Invoke-MgGraphRequest -Uri $NextLink -Method Get)
                    $NextLink = $BackupResponse."@odata.nextLink"
                    $assignments += $BackupResponse.value
                }
        

            if ($assignments) {
                $fileName = ($groupPolicyConfiguration.displayName).Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
                $assignments | ConvertTo-Json  | Out-File -Encoding utf8 -LiteralPath "$path\Administrative Templates\Assignments\$fileName.json"

                [PSCustomObject]@{
                    "Action" = "Backup"
                    "Type"   = "Administrative Template Assignments"
                    "Name"   = $groupPolicyConfiguration.displayName
                    "Path"   = "Administrative Templates\Assignments\$fileName.json"
                }
            }
        }
    ###############################################################################################################################################################
        #region Windows Updates - Driver and Firmware
        write-output Region Windows Updates - Driver and Firmware
        # Create folder if not exists
        if (-not (Test-Path "$Path\Windows Updates - Driver and Firmware")) {
            $null = New-Item -Path "$Path\Windows Updates - Driver and Firmware" -ItemType Directory
        }

        # Get all Windows Updates - Driver and Firmware
        $BackupResponse = (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/windowsDriverUpdateProfiles" -Method Get)
        $driverUpdatePolicies = $BackupResponse.value
        $NextLink = $BackupResponse."@odata.nextLink"
            while ($null -ne $NextLink){
                $BackupResponse = (Invoke-MgGraphRequest -Uri $NextLink -Method Get)
                $NextLink = $BackupResponse."@odata.nextLink"
                $driverUpdatePolicies += $BackupResponse.value
            }
        
        
        foreach ($driverUpdatePolicy in $driverUpdatePolicies) {
            $fileName = ($driverUpdatePolicy.displayName).Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
            $driverUpdatePolicy | ConvertTo-Json -Depth 100 | Out-File -Encoding utf8 -LiteralPath "$path\Windows Updates - Driver and Firmware\$fileName.json"

            [PSCustomObject]@{
                "Action" = "Backup"
                "Type"   = "Windows Updates - Driver and Firmware"
                "Name"   = $driverUpdatePolicy.displayName
                "Path"   = "Windows Updates - Driver and Firmware\$fileName.json"
            }
        }

    ###############################################################################################################################################################
        #region Windows Updates - Driver and Firmware Assignments
        write-output Region Windows Updates - Driver and Firmware Assignments
        # Create folder if not exists
        if (-not (Test-Path "$Path\Windows Updates - Driver and Firmware\Assignments")) {
            $null = New-Item -Path "$Path\Windows Updates - Driver and Firmware\Assignments" -ItemType Directory
        }

        foreach ($driverUpdatePolicy in $driverUpdatePolicies) {

            $BackupResponse = (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/windowsDriverUpdateProfiles/$($driverUpdatePolicy.id)/assignments" -Method Get)
            $assignments = $BackupResponse.value
            $NextLink = $BackupResponse."@odata.nextLink"
                while ($null -ne $NextLink){
                    $BackupResponse = (Invoke-MgGraphRequest -Uri $NextLink -Method Get)
                    $NextLink = $BackupResponse."@odata.nextLink"
                    $assignments += $BackupResponse.value
                }

            if ($assignments) {
                $fileName = ($driverUpdatePolicy.displayName).Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
                $assignments | ConvertTo-Json | Out-File -Encoding utf8 -LiteralPath "$path\Windows Updates - Driver and Firmware\Assignments\$fileName.json"

                [PSCustomObject]@{
                    "Action" = "Backup"
                    "Type"   = "Windows Updates - Driver and Firmware Assignments"
                    "Name"   = $driverUpdatePolicy.displayName
                    "Path"   = "Windows Updates - Driver and Firmware\Assignments\$fileName.json"
                }
            }
        }
    

    ###############################################################################################################################################################
        #region Windows Updates - Driver and Firmware driverInventories
        write-output Region Windows Updates - Driver and Firmware driverInventories
        # Create folder if not exists
        if (-not (Test-Path "$Path\Windows Updates - Driver and Firmware\driverInventories")) {
            $null = New-Item -Path "$Path\Windows Updates - Driver and Firmware\driverInventories" -ItemType Directory
        }

        foreach ($driverUpdatePolicy in $driverUpdatePolicies) {

            $BackupResponse = (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/windowsDriverUpdateProfiles/$($driverUpdatePolicy.id)/driverInventories" -Method Get)
            $driverInventories = $BackupResponse.value
            $NextLink = $BackupResponse."@odata.nextLink"
                while ($null -ne $NextLink){
                    $BackupResponse = (Invoke-MgGraphRequest -Uri $NextLink -Method Get)
                    $NextLink = $BackupResponse."@odata.nextLink"
                    $driverInventories += $BackupResponse.value
                }

            if ($driverInventories) {
                $fileName = ($driverUpdatePolicy.displayName).Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
                $driverInventories | ConvertTo-Json | Out-File -Encoding utf8 -LiteralPath "$path\Windows Updates - Driver and Firmware\driverInventories\$fileName.json"

                [PSCustomObject]@{
                    "Action" = "Backup"
                    "Type"   = "Windows Updates - Driver and Firmware driverInventories"
                    "Name"   = $driverUpdatePolicy.displayName
                    "Path"   = "Windows Updates - Driver and Firmware\driverInventories\$fileName.json"
                }
            }
        }
    ###############################################################################################################################################################
        #region Windows Updates - Feature Updates
        write-output Region Windows Updates - Feature Updates
        # Create folder if not exists
        if (-not (Test-Path "$Path\Windows Updates - Feature Updates")) {
            $null = New-Item -Path "$Path\Windows Updates - Feature Updates" -ItemType Directory
        }

        # Get all Windows Updates - Feature Updates
        $BackupResponse = (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/windowsFeatureUpdateProfiles" -Method Get)
        $FeatureUpdatePolicies = $BackupResponse.value
        $NextLink = $BackupResponse."@odata.nextLink"
            while ($null -ne $NextLink){
                $BackupResponse = (Invoke-MgGraphRequest -Uri $NextLink -Method Get)
                $NextLink = $BackupResponse."@odata.nextLink"
                $FeatureUpdatePolicies += $BackupResponse.value
            }
        
        
        foreach ($FeatureUpdatePolicy in $FeatureUpdatePolicies) {
            $fileName = ($FeatureUpdatePolicy.displayName).Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
            $FeatureUpdatePolicy | ConvertTo-Json -Depth 100 | Out-File -Encoding utf8 -LiteralPath "$path\Windows Updates - Feature Updates\$fileName.json"

            [PSCustomObject]@{
                "Action" = "Backup"
                "Type"   = "Windows Updates - Feature Updates"
                "Name"   = $FeatureUpdatePolicy.displayName
                "Path"   = "Windows Updates - Feature Updates\$fileName.json"
            }
        }

    ###############################################################################################################################################################
        #region Windows Updates - Feature Updates Assignments
        write-output Region Windows Updates - Feature Updates Assignments
        # Create folder if not exists
        if (-not (Test-Path "$Path\Windows Updates - Feature Updates\Assignments")) {
            $null = New-Item -Path "$Path\Windows Updates - Feature Updates\Assignments" -ItemType Directory
        }

        foreach ($FeatureUpdatePolicy in $FeatureUpdatePolicies) {

            $BackupResponse = (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/windowsFeatureUpdateProfiles/$($FeatureUpdatePolicy.id)/assignments" -Method Get)
            $assignments = $BackupResponse.value
            $NextLink = $BackupResponse."@odata.nextLink"
                while ($null -ne $NextLink){
                    $BackupResponse = (Invoke-MgGraphRequest -Uri $NextLink -Method Get)
                    $NextLink = $BackupResponse."@odata.nextLink"
                    $assignments += $BackupResponse.value
                }

            if ($assignments) {
                $fileName = ($FeatureUpdatePolicy.displayName).Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
                $assignments | ConvertTo-Json | Out-File -Encoding utf8 -LiteralPath "$path\Windows Updates - Feature Updates\Assignments\$fileName.json"

                [PSCustomObject]@{
                    "Action" = "Backup"
                    "Type"   = "Windows Updates - Feature Updates Assignments"
                    "Name"   = $FeatureUpdatePolicy.displayName
                    "Path"   = "Windows Updates - Feature Updates\Assignments\$fileName.json"
                }
            }
        }

    ###############################################################################################################################################################
        #region Windows Updates - Quality Updates
        write-output Region Windows Updates - Quality Updates
        # Create folder if not exists
        if (-not (Test-Path "$Path\Windows Updates - Quality Updates")) {
            $null = New-Item -Path "$Path\Windows Updates - Quality Updates" -ItemType Directory
        }

        # Get all Windows Updates - Quality Updates
        $BackupResponse = (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/windowsQualityUpdateProfiles" -Method Get)
        $QualityUpdatePolicies = $BackupResponse.value
        $NextLink = $BackupResponse."@odata.nextLink"
            while ($null -ne $NextLink){
                $BackupResponse = (Invoke-MgGraphRequest -Uri $NextLink -Method Get)
                $NextLink = $BackupResponse."@odata.nextLink"
                $QualityUpdatePolicies += $BackupResponse.value
            }
        
        
        foreach ($QualityUpdatePolicy in $QualityUpdatePolicies) {
            $fileName = ($QualityUpdatePolicy.displayName).Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
            $QualityUpdatePolicy | ConvertTo-Json -Depth 100 | Out-File -Encoding utf8 -LiteralPath "$path\Windows Updates - Quality Updates\$fileName.json"

            [PSCustomObject]@{
                "Action" = "Backup"
                "Type"   = "Windows Updates - Quality Updates"
                "Name"   = $QualityUpdatePolicy.displayName
                "Path"   = "Windows Updates - Quality Updates\$fileName.json"
            }
        }

    ###############################################################################################################################################################
        #region Windows Updates - Quality Updates Assignments
        write-output Region Windows Updates - Quality Updates Assignments
        # Create folder if not exists
        if (-not (Test-Path "$Path\Windows Updates - Quality Updates\Assignments")) {
            $null = New-Item -Path "$Path\Windows Updates - Quality Updates\Assignments" -ItemType Directory
        }

        foreach ($QualityUpdatePolicy in $QualityUpdatePolicies) {

            $BackupResponse = (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/windowsQualityUpdateProfiles/$($QualityUpdatePolicy.id)/assignments" -Method Get)
            $assignments = $BackupResponse.value
            $NextLink = $BackupResponse."@odata.nextLink"
                while ($null -ne $NextLink){
                    $BackupResponse = (Invoke-MgGraphRequest -Uri $NextLink -Method Get)
                    $NextLink = $BackupResponse."@odata.nextLink"
                    $assignments += $BackupResponse.value
                }

            if ($assignments) {
                $fileName = ($QualityUpdatePolicy.displayName).Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
                $assignments | ConvertTo-Json | Out-File -Encoding utf8 -LiteralPath "$path\Windows Updates - Quality Updates\Assignments\$fileName.json"

                [PSCustomObject]@{
                    "Action" = "Backup"
                    "Type"   = "Windows Updates - Quality Updates Assignments"
                    "Name"   = $QualityUpdatePolicy.displayName
                    "Path"   = "Windows Updates - Quality Updates\Assignments\$fileName.json"
                }
            }
        }

    ###############################################################################################################################################################
        #region Windows Autopilot deployment profiles
        write-output Region Windows Autopilot deployment profiles
        # Create folder if not exists
        if (-not (Test-Path "$Path\Enrollments\Windows Autopilot deployment profiles")) {
            $null = New-Item -Path "$Path\Enrollments\Windows Autopilot deployment profiles" -ItemType Directory
        }

        # Get all Windows Autopilot deployment profiles
        $BackupResponse = (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeploymentProfiles" -Method Get)
        $AutopilotDeploymentProfiles = $BackupResponse.value
        $NextLink = $BackupResponse."@odata.nextLink"
            while ($null -ne $NextLink){
                $BackupResponse = (Invoke-MgGraphRequest -Uri $NextLink -Method Get)
                $NextLink = $BackupResponse."@odata.nextLink"
                $AutopilotDeploymentProfiles += $BackupResponse.value
            }
        
        
        foreach ($AutopilotDeploymentProfile in $AutopilotDeploymentProfiles) {
            $fileName = ($AutopilotDeploymentProfile.displayName).Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
            $AutopilotDeploymentProfile | ConvertTo-Json -Depth 100 | Out-File -Encoding utf8 -LiteralPath "$path\Enrollments\Windows Autopilot deployment profiles\$fileName.json"

            [PSCustomObject]@{
                "Action" = "Backup"
                "Type"   = "Windows Autopilot deployment profiles"
                "Name"   = $AutopilotDeploymentProfile.displayName
                "Path"   = "Enrollments\Windows Autopilot deployment profiles\$fileName.json"
            }
        }

    ###############################################################################################################################################################
        #region Windows Autopilot deployment profiles Assignments
        write-output Region Windows Autopilot deployment profiles Assignments
        # Create folder if not exists
        if (-not (Test-Path "$Path\Enrollments\Windows Autopilot deployment profiles\Assignments")) {
            $null = New-Item -Path "$Path\Enrollments\Windows Autopilot deployment profiles\Assignments" -ItemType Directory
        }

        foreach ($AutopilotDeploymentProfile in $AutopilotDeploymentProfiles) {

            $BackupResponse = (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeploymentProfiles/$($AutopilotDeploymentProfile.id)/assignments" -Method Get)
            $assignments = $BackupResponse.value
            $NextLink = $BackupResponse."@odata.nextLink"
                while ($null -ne $NextLink){
                    $BackupResponse = (Invoke-MgGraphRequest -Uri $NextLink -Method Get)
                    $NextLink = $BackupResponse."@odata.nextLink"
                    $assignments += $BackupResponse.value
                }

            if ($assignments) {
                $fileName = ($AutopilotDeploymentProfile.displayName).Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
                $assignments | ConvertTo-Json | Out-File -Encoding utf8 -LiteralPath "$path\Enrollments\Windows Autopilot deployment profiles\Assignments\$fileName.json"

                [PSCustomObject]@{
                    "Action" = "Backup"
                    "Type"   = "Windows Autopilot deployment profile Assignments"
                    "Name"   = $AutopilotDeploymentProfile.displayName
                    "Path"   = "Enrollments\Windows Autopilot deployment profiles\Assignments\$fileName.json"
                }
            }
        }

    ###############################################################################################################################################################
        #region Device Enrollment Configurations
        write-output Region Device Enrollment Configurations
        # Create folder if not exists
        if (-not (Test-Path "$Path\Enrollments\Device Enrollment Configurations")) {
            $null = New-Item -Path "$Path\Enrollments\Device Enrollment Configurations" -ItemType Directory
        }

        # Get all Device Enrollment Configurations
        $BackupResponse = (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceEnrollmentConfigurations" -Method Get)
        $deviceEnrollmentConfigurations = $BackupResponse.value
        $NextLink = $BackupResponse."@odata.nextLink"
            while ($null -ne $NextLink){
                $BackupResponse = (Invoke-MgGraphRequest -Uri $NextLink -Method Get)
                $NextLink = $BackupResponse."@odata.nextLink"
                $deviceEnrollmentConfigurations += $BackupResponse.value
            }
        
        
        foreach ($deviceEnrollmentConfiguration in $deviceEnrollmentConfigurations) {
            $fileName = ($deviceEnrollmentConfiguration.displayName).Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
            $deviceEnrollmentConfiguration | ConvertTo-Json -Depth 100 | Out-File -Encoding utf8 -LiteralPath "$path\Enrollments\Device Enrollment Configurations\$fileName.json"

            [PSCustomObject]@{
                "Action" = "Backup"
                "Type"   = "Device Enrollment Configurations"
                "Name"   = $deviceEnrollmentConfiguration.displayName
                "Path"   = "Enrollments\Device Enrollment Configurations\$fileName.json"
            }
        }

    ###############################################################################################################################################################
        #region Device Enrollment Configurations Assignments
        write-output Region Device Enrollment Configurations Assignments
        # Create folder if not exists
        if (-not (Test-Path "$Path\Enrollments\Device Enrollment Configurations\Assignments")) {
            $null = New-Item -Path "$Path\Enrollments\Device Enrollment Configurations\Assignments" -ItemType Directory
        }

        foreach ($deviceEnrollmentConfiguration in $deviceEnrollmentConfigurations) {

            $BackupResponse = (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceEnrollmentConfigurations/$($deviceEnrollmentConfiguration.id)/assignments" -Method Get)
            $assignments = $BackupResponse.value
            $NextLink = $BackupResponse."@odata.nextLink"
                while ($null -ne $NextLink){
                    $BackupResponse = (Invoke-MgGraphRequest -Uri $NextLink -Method Get)
                    $NextLink = $BackupResponse."@odata.nextLink"
                    $assignments += $BackupResponse.value
                }

            if ($assignments) {
                $fileName = ($deviceEnrollmentConfiguration.displayName).Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
                $assignments | ConvertTo-Json | Out-File -Encoding utf8 -LiteralPath "$path\Enrollments\Device Enrollment Configurations\Assignments\$fileName.json"

                [PSCustomObject]@{
                    "Action" = "Backup"
                    "Type"   = "Device Enrollment Configuration Assignments"
                    "Name"   = $deviceEnrollmentConfiguration.displayName
                    "Path"   = "Enrollments\Device Enrollment Configurations\Assignments\$fileName.json"
                }
            }
        }
    
    ###############################################################################################################################################################
        #region Client Apps
        write-output Region Client Apps
        # Create folder if not exists
        if (-not (Test-Path "$Path\Client Apps")) {
            $null = New-Item -Path "$Path\Client Apps" -ItemType Directory
        }

        # Get all Client Apps

        $BackupResponse = (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps?$filter=(microsoft.graph.managedApp/appAvailability%20eq%20null%20or%20microsoft.graph.managedApp/appAvailability%20eq%20%27lineOfBusiness%27%20or%20isAssigned%20eq%20true)" -Method Get)
        $clientApps = $BackupResponse.value
        $NextLink = $BackupResponse."@odata.nextLink"
            while ($null -ne $NextLink){
                $BackupResponse = (Invoke-MgGraphRequest -Uri $NextLink -Method Get)
                $NextLink = $BackupResponse."@odata.nextLink"
                $clientApps += $BackupResponse.value
            }

        foreach ($clientApp in $clientApps) {
            $clientAppType = $clientApp.'@odata.type'.split('.')[-1]

            $fileName = ($clientApp.displayName).Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
            $clientAppDetails = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$($clientApp.id)" -Method Get
            $clientAppDetails | ConvertTo-Json  | Out-File -Encoding utf8 -LiteralPath "$path\Client Apps\$($fileName)_$($clientAppType)_$($clientApp.id).json"

            [PSCustomObject]@{
                "Action" = "Backup"
                "Type"   = "Client App"
                "Name"   = $clientApp.displayName
                "Path"   = "Client Apps\$($fileName)_$($clientAppType)_$($clientApp.id).json"
            }
        }

    ###############################################################################################################################################################
        #region Client Apps Assignments
        write-output Region Client Apps Assignments
        # Create folder if not exists
        if (-not (Test-Path "$Path\Client Apps\Assignments")) {
            $null = New-Item -Path "$Path\Client Apps\Assignments" -ItemType Directory
        }

        foreach ($clientApp in $clientApps) {
            
            $BackupResponse = (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$($clientApp.id)/assignments" -Method Get)
            $assignments = $BackupResponse.value
            $NextLink = $BackupResponse."@odata.nextLink"
                while ($null -ne $NextLink){
                    $BackupResponse = (Invoke-MgGraphRequest -Uri $NextLink -Method Get)
                    $NextLink = $BackupResponse."@odata.nextLink"
                    $assignments += $BackupResponse.value
                }
            if ($assignments) {
                $fileName = ($clientApp.displayName).Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
                $assignments | ConvertTo-Json -Depth 100 | Out-File -Encoding utf8 -LiteralPath "$path\Client Apps\Assignments\$($clientApp.id) - $fileName.json"

                [PSCustomObject]@{
                    "Action" = "Backup"
                    "Type"   = "Client App Assignments"
                    "Name"   = $clientApp.displayName
                    "Path"   = "Client Apps\Assignments\$($clientApp.id) - $fileName.json"
                }
            }
        }
