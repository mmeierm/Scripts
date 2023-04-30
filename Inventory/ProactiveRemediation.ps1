#region initialize
# Enable TLS 1.2 support 
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$Date = (Get-Date)

# add necessary assembly
#
Add-Type -AssemblyName System.Web


Function Invoke-CosmosDBFunction
{
	[CmdletBinding()]
	Param
	(
		[Parameter(Mandatory=$true)][String]$CollectionId,
		[Parameter(Mandatory=$true)][String]$JSON
	)


$JSON =[Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($JSON))
$Cos = New-Object System.Object
$Cos | Add-Member -MemberType NoteProperty -Name "CollectionId" -Value $CollectionId -Force
$Cos | Add-Member -MemberType NoteProperty -Name "JSON" -Value $JSON -Force
$CosmosDBJSON = $Cos | ConvertTo-Json
Invoke-WebRequest -Method Post -Body $CosmosDBJSON -UseBasicParsing -Uri "<INSERT Function APP URL HERE>" 


}

#endregion initialize

#region functions
# Function to get Azure AD DeviceID
function Get-AzureADDeviceID {
	Process {
		# Define Cloud Domain Join information registry path
		$AzureADJoinInfoRegistryKeyPath = "HKLM:\SYSTEM\CurrentControlSet\Control\CloudDomainJoin\JoinInfo"
		
		# Retrieve the child key name that is the thumbprint of the machine certificate containing the device identifier guid
		$AzureADJoinInfoThumbprint = Get-ChildItem -Path $AzureADJoinInfoRegistryKeyPath | Select-Object -ExpandProperty "PSChildName"
		if ($null -ne $AzureADJoinInfoThumbprint) {
			# Retrieve the machine certificate based on thumbprint from registry key
			$AzureADJoinCertificate = Get-ChildItem -Path "Cert:\LocalMachine\My" -Recurse | Where-Object { $PSItem.Thumbprint -eq $AzureADJoinInfoThumbprint }
			if ($null -ne $AzureADJoinCertificate) {
				# Determine the device identifier from the subject name
				$AzureADDeviceID = ($AzureADJoinCertificate | Select-Object -ExpandProperty "Subject") -replace "CN=", ""
				# Handle return value
				return $AzureADDeviceID
			}
		}
	}
} #endfunction 

# Function to get Azure AD Device Join Date (Currently not used - for future functionality)
function Get-AzureADJoinDate {
	Process {
		# Define Cloud Domain Join information registry path
		$AzureADJoinInfoRegistryKeyPath = "HKLM:\SYSTEM\CurrentControlSet\Control\CloudDomainJoin\JoinInfo"
		
		# Retrieve the child key name that is the thumbprint of the machine certificate containing the device identifier guid
		$AzureADJoinInfoThumbprint = Get-ChildItem -Path $AzureADJoinInfoRegistryKeyPath | Select-Object -ExpandProperty "PSChildName"
		if ($null -ne $AzureADJoinInfoThumbprint) {
			# Retrieve the machine certificate based on thumbprint from registry key
			$AzureADJoinCertificate = Get-ChildItem -Path "Cert:\LocalMachine\My" -Recurse | Where-Object { $PSItem.Thumbprint -eq $AzureADJoinInfoThumbprint }
			if ($null -ne $AzureADJoinCertificate) {
				# Determine the device identifier from the subject name
				$AzureADJoinDate = ($AzureADJoinCertificate | Select-Object -ExpandProperty "NotBefore") 
				# Handle return value
				return $AzureADJoinDate
			}
		}
	}
} #endfunction 
# Function to get all Installed Application
function Get-InstalledApplications() {
    param(
        [string]$UserSid
    )
    
    New-PSDrive -PSProvider Registry -Name "HKU" -Root HKEY_USERS | Out-Null
    $regpath = @("HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*")
    $regpath += "HKU:\$UserSid\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    if (-not ([IntPtr]::Size -eq 4)) {
        $regpath += "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
        $regpath += "HKU:\$UserSid\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    }
    $propertyNames = 'DisplayName', 'DisplayVersion', 'Publisher', 'UninstallString'
    $Apps = Get-ItemProperty $regpath -Name $propertyNames -ErrorAction SilentlyContinue | . { process { if ($_.DisplayName) { $_ } } } | Select-Object DisplayName, DisplayVersion, Publisher, UninstallString, PSPath | Sort-Object DisplayName   
    Remove-PSDrive -Name "HKU" | Out-Null
    Return $Apps
}#end function

function Get-InstalledModernApps (){

$modernApps=Get-AppxPackage -AllUsers | select-object -Property Name, Version, Architecture
return $modernApps
}





#Function to get AzureAD TenantID
function Get-AzureADTenantID {
	# Cloud Join information registry path
	$AzureADTenantInfoRegistryKeyPath = "HKLM:\SYSTEM\CurrentControlSet\Control\CloudDomainJoin\TenantInfo"
	# Retrieve the child key name that is the tenant id for AzureAD
	$AzureADTenantID = Get-ChildItem -Path $AzureADTenantInfoRegistryKeyPath | Select-Object -ExpandProperty "PSChildName"
	return $AzureADTenantID
}#end function
#endregion functions

#region script
#Get Common data for App and Device Inventory: 
#Get Intune DeviceID and ManagedDeviceName
if (@(Get-ChildItem HKLM:SOFTWARE\Microsoft\Enrollments\ -Recurse | Where-Object { $_.PSChildName -eq 'MS DM Server' })) {
    $MSDMServerInfo = Get-ChildItem HKLM:SOFTWARE\Microsoft\Enrollments\ -Recurse | Where-Object { $_.PSChildName -eq 'MS DM Server' }
    $ManagedDeviceInfo = Get-ItemProperty -LiteralPath "Registry::$($MSDMServerInfo)"
}
$ManagedDeviceName = $ManagedDeviceInfo.EntDeviceName
$ManagedDeviceID = $ManagedDeviceInfo.EntDMID
$AzureADDeviceID = Get-AzureADDeviceID
$AzureADTenantID = Get-AzureADTenantID

#Get Computer Info
$ComputerInfo = Get-CimInstance -ClassName Win32_ComputerSystem
$ComputerName = $ComputerInfo.Name
$ComputerManufacturer = $ComputerInfo.Manufacturer

if ($ComputerManufacturer -match "HP|Hewlett-Packard") {
	$ComputerManufacturer = "HP"
}
$SN=(get-wmiobject win32_bios).Serialnumber



#region DEVICEINVENTORY

	# Get Windows Update Service Settings
	$DefaultAUService = (New-Object -ComObject "Microsoft.Update.ServiceManager").Services | Where-Object { $_.isDefaultAUService -eq $True } | Select-Object Name
	$AUMeteredNetwork = (Get-ItemProperty -Path HKLM:\Software\Microsoft\WindowsUpdate\UX\Settings\).AllowAutoWindowsUpdateDownloadOverMeteredNetwork 
	if ($AUMeteredNetwork -eq "0") {
		$AUMetered = "false"
	} else { $AUMetered = "true" }
	
	
	# Get Computer Inventory Information 
	$ComputerOSInfo = Get-CimInstance -ClassName Win32_OperatingSystem
	$ComputerBIOSInfo = Get-CimInstance -ClassName Win32_BIOS
	$ComputerModel = $ComputerInfo.Model
	$ComputerLastBoot = $ComputerOSInfo.LastBootUpTime
	$ComputerUptime = [int](New-TimeSpan -Start $ComputerLastBoot -End $Date).Days
	$ComputerInstallDate = $ComputerOSInfo.InstallDate
	$DisplayVersion = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name DisplayVersion -ErrorAction SilentlyContinue).DisplayVersion
	if ([string]::IsNullOrEmpty($DisplayVersion)) {
		$ComputerWindowsVersion = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name ReleaseId).ReleaseId
	} else {
		$ComputerWindowsVersion = $DisplayVersion
	}
	$ComputerOSName = $ComputerOSInfo.Caption
	$ComputerSystemSkuNumber = $ComputerInfo.SystemSKUNumber
	$ComputerSerialNr = $ComputerBIOSInfo.SerialNumber
	$ComputerBIOSUUID = Get-CimInstance Win32_ComputerSystemProduct | Select-Object -ExpandProperty UUID
	$ComputerBIOSVersion = $ComputerBIOSInfo.SMBIOSBIOSVersion
	$ComputerBIOSDate = $ComputerBIOSInfo.ReleaseDate
	$ComputerSMBIOSAssetTag = Get-CimInstance Win32_SystemEnclosure | Select-Object -expandproperty SMBIOSAssetTag 
	$ComputerFirmwareType = $env:firmware_type
	$PCSystemType = $ComputerInfo.PCSystemType
		switch ($PCSystemType){
			0 {$ComputerPCSystemType = "Unspecified"}
			1 {$ComputerPCSystemType = "Desktop"}
			2 {$ComputerPCSystemType = "Laptop"}
			3 {$ComputerPCSystemType = "Workstation"}
			4 {$ComputerPCSystemType = "EnterpriseServer"}
			5 {$ComputerPCSystemType = "SOHOServer"}
			6 {$ComputerPCSystemType = "AppliancePC"}
			7 {$ComputerPCSystemType = "PerformanceServer"}
			8 {$ComputerPCSystemType = "Maximum"}
			default {$ComputerPCSystemType = "Unspecified"}
		}
	$PCSystemTypeEx = $ComputerInfo.PCSystemTypeEx
		switch ($PCSystemTypeEx){
			0 {$ComputerPCSystemTypeEx = "Unspecified"}
			1 {$ComputerPCSystemTypeEx = "Desktop"}
			2 {$ComputerPCSystemTypeEx = "Laptop"}
			3 {$ComputerPCSystemTypeEx = "Workstation"}
			4 {$ComputerPCSystemTypeEx = "EnterpriseServer"}
			5 {$ComputerPCSystemTypeEx = "SOHOServer"}
			6 {$ComputerPCSystemTypeEx = "AppliancePC"}
			7 {$ComputerPCSystemTypeEx = "PerformanceServer"}
			8 {$ComputerPCSystemTypeEx = "Slate"}
			9 {$ComputerPCSystemTypeEx = "Maximum"}
			default {$ComputerPCSystemTypeEx = "Unspecified"}
		}
		
	$ComputerPhysicalMemory = [Math]::Round(($ComputerInfo.TotalPhysicalMemory / 1GB))
	$ComputerOSBuild = $ComputerOSInfo.BuildNumber
	$ComputerOSRevision = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name UBR).UBR
	$ComputerCPU = Get-CimInstance win32_processor | Select-Object Name, Manufacturer, NumberOfCores, NumberOfLogicalProcessors
	$ComputerProcessorManufacturer = $ComputerCPU.Manufacturer | Get-Unique
	$ComputerProcessorName = $ComputerCPU.Name | Get-Unique
	$ComputerNumberOfCores = $ComputerCPU.NumberOfCores | Get-Unique
	$ComputerNumberOfLogicalProcessors = $ComputerCPU.NumberOfLogicalProcessors | Get-Unique
	$ComputerSystemSKU = (Get-CIMInstance -ClassName MS_SystemInformation -NameSpace root\WMI).SystemSku.Trim()
	
	try {
		$TPMValues = Get-Tpm -ErrorAction SilentlyContinue | Select-Object -Property TPMReady, TPMPresent, TPMEnabled, TPMActivated, ManagedAuthLevel
	} catch {
		$TPMValues = $null
	}
	
	try {
		$ComputerTPMThumbprint = (Get-TpmEndorsementKeyInfo).AdditionalCertificates.Thumbprint
	} catch {
		$ComputerTPMThumbprint = $null
	}
	
	try {
		$BitLockerInfo = Get-BitLockerVolume -MountPoint $env:SystemDrive | Select-Object -Property *
	} catch {
		$BitLockerInfo = $null
	}
	
	$ComputerTPMReady = $TPMValues.TPMReady
	$ComputerTPMPresent = $TPMValues.TPMPresent
	$ComputerTPMEnabled = $TPMValues.TPMEnabled
	$ComputerTPMActivated = $TPMValues.TPMActivated
	
	$ComputerBitlockerCipher = $BitLockerInfo.EncryptionMethod
	$ComputerBitlockerStatus = $BitLockerInfo.VolumeStatus
	$ComputerBitlockerProtection = $BitLockerInfo.ProtectionStatus
	$ComputerDefaultAUService = $DefaultAUService.Name
	$ComputerAUMetered = $AUMetered
	
	# Get BIOS information
	# Determine manufacturer specific information
	switch -Wildcard ($ComputerManufacturer) {
		"*Microsoft*" {
			$ComputerManufacturer = "Microsoft"
			$ComputerModel = (Get-CIMInstance -Class Win32_ComputerSystem | Select-Object -ExpandProperty Model).Trim()
			$ComputerSystemSKU = Get-CIMInstance -Namespace root\wmi -Class MS_SystemInformation | Select-Object -ExpandProperty SystemSKU
		}
		"*HP*" {
			$ComputerModel = (Get-CIMInstance  -Class Win32_ComputerSystem | Select-Object -ExpandProperty Model).Trim()
			$ComputerSystemSKU = (Get-CIMInstance -ClassName MS_SystemInformation -NameSpace root\WMI).BaseBoardProduct.Trim()
			
			# Obtain current BIOS release
			$CurrentBIOSProperties = (Get-CIMInstance -Class Win32_BIOS | Select-Object -Property *)
			
			# Detect new versus old BIOS formats
			switch -wildcard ($($CurrentBIOSProperties.SMBIOSBIOSVersion)) {
				"*ver*" {
					if ($CurrentBIOSProperties.SMBIOSBIOSVersion -match '.F.\d+$') {
						$ComputerBIOSVersion = ($CurrentBIOSProperties.SMBIOSBIOSVersion -split "Ver.")[1].Trim()
					} else {
						$ComputerBIOSVersion = [System.Version]::Parse(($CurrentBIOSProperties.SMBIOSBIOSVersion).TrimStart($CurrentBIOSProperties.SMBIOSBIOSVersion.Split(".")[0]).TrimStart(".").Trim().Split(" ")[0])
					}
				}
				default {
					$ComputerBIOSVersion = "$($CurrentBIOSProperties.SystemBIOSMajorVersion).$($CurrentBIOSProperties.SystemBIOSMinorVersion)"
				}
			}
		}
		"*Dell*" {
			$ComputerManufacturer = "Dell"
			$ComputerModel = (Get-CIMInstance -Class Win32_ComputerSystem | Select-Object -ExpandProperty Model).Trim()
			$ComputerSystemSKU = (Get-CIMInstance -ClassName MS_SystemInformation -NameSpace root\WMI).SystemSku.Trim()
			
			# Obtain current BIOS release
			$ComputerBIOSVersion = (Get-CIMInstance -Class Win32_BIOS | Select-Object -ExpandProperty SMBIOSBIOSVersion).Trim()
			
		}
		"*Lenovo*" {
			$ComputerManufacturer = "Lenovo"
			$ComputerModel = (Get-CIMInstance -Class Win32_ComputerSystemProduct | Select-Object -ExpandProperty Version).Trim()
			$ComputerSystemSKU = ((Get-CIMInstance -Class Win32_ComputerSystem | Select-Object -ExpandProperty Model).SubString(0, 4)).Trim()
			
			# Obtain current BIOS release
			$CurrentBIOSProperties = (Get-CIMInstance -Class Win32_BIOS | Select-Object -Property *)
			
			# Obtain current BIOS release
			#$ComputerBIOSVersion = ((Get-WmiObject -Class Win32_BIOS | Select-Object -Property *).SMBIOSBIOSVersion).SubString(0, 8)
			$ComputerBIOSVersion = "$($CurrentBIOSProperties.SystemBIOSMajorVersion).$($CurrentBIOSProperties.SystemBIOSMinorVersion)"
		}
	}
	
	#Get network adapters
	$NetWorkArray = @()
	
	$CurrentNetAdapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
	
	foreach ($CurrentNetAdapter in $CurrentNetAdapters) {
		$IPConfiguration = Get-NetIPConfiguration -InterfaceIndex $CurrentNetAdapter[0].ifIndex
		$ComputerNetInterfaceDescription = $CurrentNetAdapter.InterfaceDescription
		$ComputerNetProfileName = $IPConfiguration.NetProfile.Name
		$ComputerNetIPv4Adress = $IPConfiguration.IPv4Address.IPAddress
		$ComputerNetInterfaceAlias = $CurrentNetAdapter.InterfaceAlias
		$ComputerNetIPv4DefaultGateway = $IPConfiguration.IPv4DefaultGateway.NextHop
		$ComputerNetMacAddress = $CurrentNetAdapter.MacAddress
		
		$tempnetwork = New-Object -TypeName PSObject
		$tempnetwork | Add-Member -MemberType NoteProperty -Name "NetInterfaceDescription" -Value "$ComputerNetInterfaceDescription" -Force
		$tempnetwork | Add-Member -MemberType NoteProperty -Name "NetProfileName" -Value "$ComputerNetProfileName" -Force
		$tempnetwork | Add-Member -MemberType NoteProperty -Name "NetIPv4Adress" -Value "$ComputerNetIPv4Adress" -Force
		$tempnetwork | Add-Member -MemberType NoteProperty -Name "NetInterfaceAlias" -Value "$ComputerNetInterfaceAlias" -Force
		$tempnetwork | Add-Member -MemberType NoteProperty -Name "NetIPv4DefaultGateway" -Value "$ComputerNetIPv4DefaultGateway" -Force
		$tempnetwork | Add-Member -MemberType NoteProperty -Name "MacAddress" -Value "$ComputerNetMacAddress" -Force
		$NetWorkArray += $tempnetwork
	}
	[System.Collections.ArrayList]$NetWorkArrayList = $NetWorkArray
	
	# Get Disk Health
	$DiskArray = @()
	$Disks = Get-PhysicalDisk | Where-Object { $_.BusType -match "NVMe|SATA|SAS|ATAPI|RAID" }
	
	# Loop through each disk
	foreach ($Disk in ($Disks | Sort-Object DeviceID)) {
		# Obtain disk health information from current disk
		$DiskHealth = Get-PhysicalDisk -UniqueId $($Disk.UniqueId) | Get-StorageReliabilityCounter | Select-Object -Property Wear, ReadErrorsTotal, ReadErrorsUncorrected, WriteErrorsTotal, WriteErrorsUncorrected, Temperature, TemperatureMax
		
		# Obtain media type
		$DriveDetails = Get-PhysicalDisk -UniqueId $($Disk.UniqueId) | Select-Object MediaType, HealthStatus
		$DriveMediaType = $DriveDetails.MediaType
		$DriveHealthState = $DriveDetails.HealthStatus
		$DiskTempDelta = [int]$($DiskHealth.Temperature) - [int]$($DiskHealth.TemperatureMax)
		
		# Create custom PSObject
		$DiskHealthState = new-object -TypeName PSObject
		
		# Create disk entry
		$DiskHealthState | Add-Member -MemberType NoteProperty -Name "Disk Number" -Value $Disk.DeviceID
		$DiskHealthState | Add-Member -MemberType NoteProperty -Name "FriendlyName" -Value $($Disk.FriendlyName)
		$DiskHealthState | Add-Member -MemberType NoteProperty -Name "HealthStatus" -Value $DriveHealthState
		$DiskHealthState | Add-Member -MemberType NoteProperty -Name "MediaType" -Value $DriveMediaType
		$DiskHealthState | Add-Member -MemberType NoteProperty -Name "Disk Wear" -Value $([int]($DiskHealth.Wear))
		$DiskHealthState | Add-Member -MemberType NoteProperty -Name "Disk $($Disk.DeviceID) Read Errors" -Value $([int]($DiskHealth.ReadErrorsTotal))
		$DiskHealthState | Add-Member -MemberType NoteProperty -Name "Disk $($Disk.DeviceID) Temperature Delta" -Value $DiskTempDelta
		$DiskHealthState | Add-Member -MemberType NoteProperty -Name "Disk $($Disk.DeviceID) ReadErrorsUncorrected" -Value $($Disk.ReadErrorsUncorrected)
		$DiskHealthState | Add-Member -MemberType NoteProperty -Name "Disk $($Disk.DeviceID) ReadErrorsTotal" -Value $($Disk.ReadErrorsTotal)
		$DiskHealthState | Add-Member -MemberType NoteProperty -Name "Disk $($Disk.DeviceID) WriteErrorsUncorrected" -Value $($Disk.WriteErrorsUncorrected)
		$DiskHealthState | Add-Member -MemberType NoteProperty -Name "Disk $($Disk.DeviceID) WriteErrorsTotal" -Value $($Disk.WriteErrorsTotal)
		
		$DiskArray += $DiskHealthState
		[System.Collections.ArrayList]$DiskHealthArrayList = $DiskArray
	}
	
	#Get Monitor Infos

	# Reads the 4 bytes following $index from $array then returns them as an integer interpreted in little endian
function Get-LittleEndianInt($array, $index) {
    # Create a new temporary array to reverse the endianness in
    $temp = @(0) * 4
    [Array]::Copy($array, $index, $temp, 0, 4)
    [Array]::Reverse($temp)
    
    # Then convert the byte data to an integer
    [System.BitConverter]::ToInt32($temp, 0)
}


# Iterate through the monitors in Device Manager
$monitorInfo = @()
gwmi Win32_PnPEntity -Filter "Service='monitor'" | ForEach-Object { $k=0 } {
    $mi = @{}
    $mi.Caption = $_.Caption
    $mi.DeviceID = $_.DeviceID
    # Then look up its data in the registry
    $path = "HKLM:\SYSTEM\CurrentControlSet\Enum\" + $_.DeviceID + "\Device Parameters"
    $edid = (Get-ItemProperty $path EDID -ErrorAction SilentlyContinue).EDID

    # Some monitors, especially those attached to VMs either don't have a Device Parameters key or an EDID value. Skip these
    if ($edid -ne $null) {
        # Collect the information from the EDID array in a hashtable
        $mi.Manufacturer += [char](64 + [Int32]($edid[8] / 4))
        $mi.Manufacturer += [char](64 + [Int32]($edid[8] % 4) * 8 + [Int32]($edid[9] / 32))
        $mi.Manufacturer += [char](64 + [Int32]($edid[9] % 32))
        $mi.ManufacturingWeek = $edid[16]
        $mi.ManufacturingYear = $edid[17] + 1990
        $mi.HorizontalSize = $edid[21]
        $mi.VerticalSize = $edid[22]
        $mi.DiagonalSize = [Math]::Round([Math]::Sqrt($mi.HorizontalSize*$mi.HorizontalSize + $mi.VerticalSize*$mi.VerticalSize) / 2.54)

        # Walk through the four descriptor fields
        for ($i = 54; $i -lt 109; $i += 18) {
            # Check if one of the descriptor fields is either the serial number or the monitor name
            # If yes, extract the 13 bytes that contain the text and append them into a string
            if ((Get-LittleEndianInt $edid $i) -eq 0xff) {
                for ($j = $i+5; $edid[$j] -ne 10 -and $j -lt $i+18; $j++) { $mi.SerialNumber += [char]$edid[$j] }
            }
            if ((Get-LittleEndianInt $edid $i) -eq 0xfc) {
                for ($j = $i+5; $edid[$j] -ne 10 -and $j -lt $i+18; $j++) { $mi.Name += [char]$edid[$j] }
            }
        }
        
        # If the horizontal size of this monitor is zero, it's a purely virtual one (i.e. RDP only) and shouldn't be stored
        if ($mi.HorizontalSize -ne 0) {
            $monitorInfo += $mi
        }
    }
    
}


$MonitorArray = @()
$monitorInfo | ForEach-Object { $i=0 } {
		$tempmon = New-Object -TypeName PSObject
		$tempmon | Add-Member -MemberType NoteProperty -Name "DeviceID" -Value $_.DeviceID -ErrorAction SilentlyContinue
		$tempmon | Add-Member -MemberType NoteProperty -Name "ManufacturingYear" -Value $_.ManufacturingYear -ErrorAction SilentlyContinue
		$tempmon | Add-Member -MemberType NoteProperty -Name "ManufacturingWeek" -Value $_.ManufacturingWeek -ErrorAction SilentlyContinue
		$tempmon | Add-Member -MemberType NoteProperty -Name "DiagonalSize" -Value $_.DiagonalSize -ErrorAction SilentlyContinue
		$tempmon | Add-Member -MemberType NoteProperty -Name "Manufacturer" -Value $_.Manufacturer -ErrorAction SilentlyContinue
		$tempmon | Add-Member -MemberType NoteProperty -Name "Name" $_.Name -Value -ErrorAction SilentlyContinue
        $tempmon | Add-Member -MemberType NoteProperty -Name "SerialNumber" -Value $_.SerialNumber -ErrorAction SilentlyContinue
        $tempmon | Add-Member -MemberType NoteProperty -Name "Description" -Value $_.Caption -ErrorAction SilentlyContinue
		$MonitorArray += $tempmon
    }
    $i++
    [System.Collections.ArrayList]$MonitorArrayList = $MonitorArray
#endregion Monitor
	
	# Create JSON to Upload to Log Analytics
	$Inventory = New-Object System.Object
    $date = get-date -format o
    $Inventory | Add-Member -MemberType NoteProperty -Name "id" -Value "$ManagedDeviceID" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "ManagedDeviceName" -Value "$ManagedDeviceName" -Force
    $Inventory | Add-Member -MemberType NoteProperty -Name "AzureADDeviceID" -Value "$AzureADDeviceID" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "ManagedDeviceID" -Value "$ManagedDeviceID" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "ComputerName" -Value "$ComputerName" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "Model" -Value "$ComputerModel" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "Manufacturer" -Value "$ComputerManufacturer" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "PCSystemType" -Value "$ComputerPCSystemType" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "PCSystemTypeEx" -Value "$ComputerPCSystemTypeEx" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "ComputerUpTime" -Value "$ComputerUptime" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "LastBoot" -Value "$ComputerLastBoot" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "InstallDate" -Value "$ComputerInstallDate" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "WindowsVersion" -Value "$ComputerWindowsVersion" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "DefaultAUService" -Value "$ComputerDefaultAUService" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "AUMetered" -Value "$ComputerAUMetered" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "SystemSkuNumber" -Value "$ComputerSystemSkuNumber" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "SerialNumber" -Value "$ComputerSerialNr" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "SMBIOSUUID" -Value "$ComputerBIOSUUID" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "SMBIOSAssetTag" -Value "$ComputerSMBIOSAssetTag" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "BIOSVersion" -Value "$ComputerBIOSVersion" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "BIOSDate" -Value "$ComputerBIOSDate" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "SystemSKU" -Value "$ComputerSystemSKU" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "FirmwareType" -Value "$ComputerFirmwareType" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "Memory" -Value "$ComputerPhysicalMemory" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "OSBuild" -Value "$ComputerOSBuild" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "OSRevision" -Value "$ComputerOSRevision" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "OSName" -Value "$ComputerOSName" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "CPUManufacturer" -Value "$ComputerProcessorManufacturer" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "CPUName" -Value "$ComputerProcessorName" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "CPUCores" -Value "$ComputerNumberOfCores" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "CPULogical" -Value "$ComputerNumberOfLogicalProcessors" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "TPMReady" -Value "$ComputerTPMReady" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "TPMPresent" -Value "$ComputerTPMPresent" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "TPMEnabled" -Value "$ComputerTPMEnabled" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "TPMActived" -Value "$ComputerTPMActivated" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "TPMThumbprint" -Value "$ComputerTPMThumbprint" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "BitlockerCipher" -Value "$ComputerBitlockerCipher" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "BitlockerVolumeStatus" -Value "$ComputerBitlockerStatus" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "BitlockerProtectionStatus" -Value "$ComputerBitlockerProtection" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "NetworkAdapters" -Value $NetWorkArrayList -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "DiskHealth" -Value $DiskHealthArrayList -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "MonitorInfos" -Value $MonitorArrayList -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "DateGenerated" -Value "$date" -Force
	
	
	$Devicejson = $Inventory | ConvertTo-Json
	

#endregion DEVICEINVENTORY

#region APPINVENTORY

	#$AppLog = "AppInventory"
	
	#Get SID of current interactive users
	$CurrentLoggedOnUser = (Get-CimInstance win32_computersystem).UserName
	if (-not ([string]::IsNullOrEmpty($CurrentLoggedOnUser))) {
		$AdObj = New-Object System.Security.Principal.NTAccount($CurrentLoggedOnUser)
		$strSID = $AdObj.Translate([System.Security.Principal.SecurityIdentifier])
		$UserSid = $strSID.Value
	} else {
		$UserSid = $null
	}
	
	#Get Apps for system and current user
	$MyApps = Get-InstalledApplications -UserSid $UserSid
	$UniqueApps = ($MyApps | Group-Object Displayname | Where-Object { $_.Count -eq 1 }).Group
	$DuplicatedApps = ($MyApps | Group-Object Displayname | Where-Object { $_.Count -gt 1 }).Group
	$NewestDuplicateApp = ($DuplicatedApps | Group-Object DisplayName) | ForEach-Object { $_.Group | Sort-Object [version]DisplayVersion -Descending | Select-Object -First 1 }
	$CleanAppList = $UniqueApps + $NewestDuplicateApp | Sort-Object DisplayName
	
	$AppArray = @()
	foreach ($App in $CleanAppList) {
		$tempapp = New-Object -TypeName PSObject
		$tempapp | Add-Member -MemberType NoteProperty -Name "AppName" -Value $App.DisplayName -Force
		$tempapp | Add-Member -MemberType NoteProperty -Name "AppVersion" -Value $App.DisplayVersion -Force
		$tempapp | Add-Member -MemberType NoteProperty -Name "AppInstallDate" -Value $App.InstallDate -Force -ErrorAction SilentlyContinue
		$tempapp | Add-Member -MemberType NoteProperty -Name "AppPublisher" -Value $App.Publisher -Force
		$tempapp | Add-Member -MemberType NoteProperty -Name "AppUninstallString" -Value $App.UninstallString -Force
		$tempapp | Add-Member -MemberType NoteProperty -Name "AppUninstallRegPath" -Value $app.PSPath.Split("::")[-1]
		$AppArray += $tempapp
	}
    [System.Collections.ArrayList]$AppArrayList = $AppArray

        $Inventory = New-Object System.Object
        $date = get-date -format o
        $Inventory | Add-Member -MemberType NoteProperty -Name "id" -Value "$ManagedDeviceID" -Force
		$Inventory | Add-Member -MemberType NoteProperty -Name "ComputerName" -Value "$ComputerName" -Force
		$Inventory | Add-Member -MemberType NoteProperty -Name "ManagedDeviceName" -Value "$ManagedDeviceName" -Force
		$Inventory | Add-Member -MemberType NoteProperty -Name "ManagedDeviceID" -Value "$ManagedDeviceID" -Force
        $Inventory | Add-Member -MemberType NoteProperty -Name "InstalledApps" -Value $AppArrayList -Force
        $Inventory | Add-Member -MemberType NoteProperty -Name "DateGenerated" -Value "$date" -Force
	
	$Appjson = $Inventory | ConvertTo-Json

#endregion APPINVENTORY

#region ModernAppInventory
$InstalledmodernApps = Get-InstalledModernApps

$MAppArray = @()
	foreach ($App in $InstalledmodernApps) {
		$tempmapp = New-Object -TypeName PSObject
		$tempmapp | Add-Member -MemberType NoteProperty -Name "AppName" -Value $App.Name -Force
		$tempmapp | Add-Member -MemberType NoteProperty -Name "AppVersion" -Value $App.Version -Force
        $temparch=$App.architecture.ToString()
		$tempmapp | Add-Member -MemberType NoteProperty -Name "AppArchitecture" -Value $temparch -Force
		$MAppArray += $tempmapp
	}
    [System.Collections.ArrayList]$MAppArrayList = $MAppArray

        $Inventory = New-Object System.Object
        $date = get-date -format o
        $Inventory | Add-Member -MemberType NoteProperty -Name "id" -Value "$ManagedDeviceID" -Force
		$Inventory | Add-Member -MemberType NoteProperty -Name "ComputerName" -Value "$ComputerName" -Force
		$Inventory | Add-Member -MemberType NoteProperty -Name "ManagedDeviceName" -Value "$ManagedDeviceName" -Force
		$Inventory | Add-Member -MemberType NoteProperty -Name "ManagedDeviceID" -Value "$ManagedDeviceID" -Force
        $Inventory | Add-Member -MemberType NoteProperty -Name "InstalledApps" -Value $MAppArrayList -Force
        $Inventory | Add-Member -MemberType NoteProperty -Name "DateGenerated" -Value "$date" -Force
	
	$ModernAppjson = $Inventory | ConvertTo-Json



#endregion ModernAppInventory


#region DriverINVENTORY


	$DriverList = Get-WmiObject Win32_PnPSignedDriver| Select-Object devicename, driverversion, driverprovidername | where-object {$PSItem.driverprovidername -notlike "" -and $PSItem.driverprovidername -notlike "*Microsoft*"}
	
	$DriverArray = @()
	foreach ($Driver in $DriverList) {
	
	# Do some formatting for Intel drivers as the vendor name is not consistent
    If ($Driver.driverprovidername -like "*Intel*")
    {
        $Driver.driverprovidername = "Intel"
    }
	$DriverVendor=$Driver.driverprovidername
	$DeviceName=$Driver.devicename
	$DriverVersion=$Driver.driverversion
	
		$tempdriver = New-Object -TypeName PSObject
		$tempdriver | Add-Member -MemberType NoteProperty -Name "DriverVendor" -Value "$DriverVendor" -Force
		$tempdriver | Add-Member -MemberType NoteProperty -Name "DeviceName" -Value "$DeviceName" -Force
		$tempdriver | Add-Member -MemberType NoteProperty -Name "DriverVersion" -Value "$DriverVersion" -Force
		$DriverArray += $tempdriver
	}
	[System.Collections.ArrayList]$DriverArrayList = $DriverArray
	
		# Create JSON to Upload to Log Analytics
		$Inventory = New-Object System.Object
        $date = get-date -format o
        $Inventory | Add-Member -MemberType NoteProperty -Name "id" -Value "$ManagedDeviceID" -Force
		$Inventory | Add-Member -MemberType NoteProperty -Name "ComputerName" -Value "$ComputerName" -Force
		$Inventory | Add-Member -MemberType NoteProperty -Name "SerialNumber" -Value "$SN" -Force
		$Inventory | Add-Member -MemberType NoteProperty -Name "ManagedDeviceName" -Value "$ManagedDeviceName" -Force
		$Inventory | Add-Member -MemberType NoteProperty -Name "AzureADDeviceID" -Value "$AzureADDeviceID" -Force
		$Inventory | Add-Member -MemberType NoteProperty -Name "ManagedDeviceID" -Value "$ManagedDeviceID" -Force
		$Inventory | Add-Member -MemberType NoteProperty -Name "InstalledDrivers" -Value $DriverArrayList -Force
		$Inventory | Add-Member -MemberType NoteProperty -Name "DateGenerated" -Value "$date" -Force
		$Driverjson = $Inventory | ConvertTo-Json

#endregion DriverINVENTORY

#region SecurityINVENTORY

#BitlockerPCRs
$namespaceName = "ROOT\CIMV2\Security\MicrosoftVolumeEncryption"
$className = "Win32_EncryptableVolume"
$methodName = "GetKeyProtectorPlatformValidationProfile"
$id=((Get-BitLockerVolume C:).KeyProtector | where-Object -Property KeyProtectorType -EQ -Value "TPM").KeyProtectorId

$session = New-CimSession
$params = New-Object Microsoft.Management.Infrastructure.CimMethodParametersCollection
$param = [Microsoft.Management.Infrastructure.CimMethodParameter]::Create("VolumeKeyProtectorID", $id, "String", "In")
$params.Add($param)

$instance = Get-CimInstance -Namespace $namespaceName -ClassName $className
$result=($session.InvokeMethod($namespaceName, $instance, $methodName, $params)).OutParameters | where-Object -Property Name -EQ -Value "PlatformValidationProfile"
$PCR=$result.value -join '; '

#KernelDMA Check from https://github.com/MicrosoftDocs/windows-itpro-docs/issues/6878

# bootDMAProtection check
$bootDMAProtectionCheck =
@"
  namespace SystemInfo
    {
      using System;
      using System.Runtime.InteropServices;

      public static class NativeMethods
      {
        internal enum SYSTEM_DMA_GUARD_POLICY_INFORMATION : int
        {
            /// </summary>
            SystemDmaGuardPolicyInformation = 202
        }

        [DllImport("ntdll.dll")]
        internal static extern Int32 NtQuerySystemInformation(
          SYSTEM_DMA_GUARD_POLICY_INFORMATION SystemDmaGuardPolicyInformation,
          IntPtr SystemInformation,
          Int32 SystemInformationLength,
          out Int32 ReturnLength);

        public static byte BootDmaCheck() {
          Int32 result;
          Int32 SystemInformationLength = 1;
          IntPtr SystemInformation = Marshal.AllocHGlobal(SystemInformationLength);
          Int32 ReturnLength;

          result = NativeMethods.NtQuerySystemInformation(
                    NativeMethods.SYSTEM_DMA_GUARD_POLICY_INFORMATION.SystemDmaGuardPolicyInformation,
                    SystemInformation,
                    SystemInformationLength,
                    out ReturnLength);

          if (result == 0) {
            byte info = Marshal.ReadByte(SystemInformation, 0);
            return info;
          }

          return 0;
        }
      }
    }
"@

Add-Type -TypeDefinition $bootDMAProtectionCheck

# returns true or false depending on whether Kernel DMA Protection is on or off
$bootDMAProtection = ([SystemInfo.NativeMethods]::BootDmaCheck()) -ne 0


#SecureBoot
$SecureBoot = Confirm-SecureBootUEFI

#ComputerInfo
$ComInfo=Get-ComputerInfo

$DevGuard=Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard

$DeviceGuardRequiredSecurityProperties=$DevGuard.RequiredSecurityProperties -join '; '
$DeviceGuardAvailableSecurityProperties=$DevGuard.AvailableSecurityProperties -join '; '
$DeviceGuardSecurityServicesConfigured=$DevGuard.SecurityServicesConfigured -join '; '
$DeviceGuardSecurityServicesRunning=$DevGuard.SecurityServicesRunning -join '; '

		# Create JSON to Upload to Log Analytics
		$Inventory = New-Object System.Object
        $date = get-date -format o
        $Inventory | Add-Member -MemberType NoteProperty -Name "id" -Value "$ManagedDeviceID" -Force
		$Inventory | Add-Member -MemberType NoteProperty -Name "BitlockerPCRs" -Value $PCR -Force
		$Inventory | Add-Member -MemberType NoteProperty -Name "SecureBootState" -Value $SecureBoot -Force
		$Inventory | Add-Member -MemberType NoteProperty -Name "KernelDMA" -Value $bootDMAProtection -Force
		$Inventory | Add-Member -MemberType NoteProperty -Name "HyperVisorPresent" -Value $ComInfo.HyperVisorPresent -Force
		$Inventory | Add-Member -MemberType NoteProperty -Name "DeviceGuardRequiredSecurityProperties" -Value $DeviceGuardRequiredSecurityProperties -Force
		$Inventory | Add-Member -MemberType NoteProperty -Name "DeviceGuardAvailableSecurityProperties" -Value $DeviceGuardAvailableSecurityProperties -Force
		$Inventory | Add-Member -MemberType NoteProperty -Name "DeviceGuardSecurityServicesConfigured" -Value $DeviceGuardSecurityServicesConfigured -Force
		$Inventory | Add-Member -MemberType NoteProperty -Name "DeviceGuardSecurityServicesRunning" -Value $DeviceGuardSecurityServicesRunning -Force
		$Inventory | Add-Member -MemberType NoteProperty -Name "DateGenerated" -Value "$date" -Force
		$SecuritySettingsjson = $Inventory | ConvertTo-Json

#endregion SecurityINVENTORY

# Submit the data to the API endpoint
Invoke-CosmosDBFunction -CollectionId "InventoryContainer" -JSON $Devicejson
Invoke-CosmosDBFunction -CollectionId "AppContainer" -JSON $Appjson
Invoke-CosmosDBFunction -CollectionId "ModernAppContainer" -JSON $ModernAppjson
Invoke-CosmosDBFunction -CollectionId "DriverContainer" -JSON $Driverjson
Invoke-CosmosDBFunction -CollectionId "SecuritySettingsContainer" -JSON $SecuritySettingsjson

#Report back status
$date = Get-Date -Format "dd-MM HH:mm"
$OutputMessage = "InventoryDate:$date "


Write-Output $OutputMessage
Exit 0
