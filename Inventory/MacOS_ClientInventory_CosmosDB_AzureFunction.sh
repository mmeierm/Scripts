#!/bin/bash

# Upload custom inventory data to Azure Cosmos DB
# This script is intended to be used with Microsoft Intune for macOS


# Gather OS Information
os_version=$(sw_vers -productVersion)
OSBuild=$(sw_vers -buildVersion)
os_friendly=$(awk '/SOFTWARE LICENSE AGREEMENT FOR macOS/' '/System/Library/CoreServices/Setup Assistant.app/Contents/Resources/en.lproj/OSXSoftwareLicense.rtf' | awk -F 'macOS ' '{print $NF}' | awk '{print substr($0, 0, length($0)-1)}')

# Gather SIP Status
sip_status=$(csrutil status)
if [[ $sip_status == *"enabled"* ]]; then
    sip_status="enabled"
elif [[ $sip_status == *"disabled"* ]]; then
    sip_status="disabled"
else
    sip_status="unknown"
fi

# Gather Secure Boot Status
secure_boot_status=$(system_profiler SPiBridgeDataType | awk -F': ' '/Secure Boot/ {print $2}')

# Gather Device Information
DeviceName=$(scutil --get ComputerName)
SerialNumber=$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')
Chip=$(sysctl -n machdep.cpu.brand_string)
Memory=$(sysctl -n hw.memsize | awk '{print $0/1024/1024 " MB"}')

# Get FileVault Status
filevault_status=$(fdesetup status)
if [[ $filevault_status == *"FileVault is On."* ]]; then
    filevault_status="Enabled"
elif [[ $filevault_status == *"FileVault is Off."* ]]; then
    filevault_status="Disabled"
else
    filevault_status="Unknown"
fi

# Storage Information
Storage_Total=$(df -Hl | grep '/System/Volumes/Data' | awk '{print $2}')
Storage_Free=$(df -Hl | grep '/System/Volumes/Data' | awk '{print $4}')

# Last Boot Time
LastBoot=$(sysctl -n kern.boottime | awk '{print $4}' | sed 's/,//')
LastBootFormatted=$(date -jf "%s" "$LastBoot" +"%m/%d/%Y, %I:%M:%S %p")

# Get Model
Model=$(system_profiler SPHardwareDataType | awk -F: '/Model Name/ {print $2}' | sed 's/^ *//')

# Extract Device ID
LOG_DIR="$HOME/Library/Logs/Microsoft/Intune"
DEVICE_ID=$(grep 'DeviceId:' "$LOG_DIR"/*.log | awk -F ': ' '{print $2}' | sort | uniq)

# Extract Entra Tenant ID
TENANT_ID=$(grep 'AADTenantID:' "$LOG_DIR"/*.log | awk -F ': ' '{print $2}' | sort | uniq)

# Get Local Admins
LocalAdmins=$(dscl . -read /Groups/admin GroupMembership | awk '{for (i=2; i<=NF; i++) printf $i " "; print ""}')

# Prepare JSON Data, LAW expects JSON format uploads
jsonData="{
\"id\": \"${DEVICE_ID}\",
\"DeviceName\": \"${DeviceName}\",
\"SerialNumber\": \"${SerialNumber}\",
\"Model\": \"${Model}\",
\"OSVersion\": \"${os_version}\",
\"OSBuild\": \"${OSBuild}\",
\"OSFriendlyName\": \"${os_friendly}\",
\"SIPStatus\": \"${sip_status}\",
\"SecureBootStatus\": \"${secure_boot_status}\",
\"Chip\": \"${Chip}\",
\"Memory\": \"${Memory}\",
\"FileVaultStatus\": \"${filevault_status}\",
\"StorageTotal\": \"${Storage_Total}\",
\"StorageFree\": \"${Storage_Free}\",
\"LastBoot\": \"${LastBootFormatted}\",
\"DeviceID\": \"${DEVICE_ID}\",
\"EntraTenantID\": \"${TENANT_ID}\",
\"LocalAdmins\": \"${LocalAdmins}\"
}"

#echo "JSON Data: $jsonData"
jsonbase64=$(echo -ne $jsonData | iconv -f utf-8 -t utf-16le | base64)

jsonup="{
\"CollectionId\": \"MacOSInventoryContainer\",
\"JSON\": \"${jsonbase64}\"
}"

# Send Data to Azure Cosmos DB
response=$(curl --data "$jsonup" -w "%{http_code}" --request POST "<INSERT Function APP URL HERE>")

