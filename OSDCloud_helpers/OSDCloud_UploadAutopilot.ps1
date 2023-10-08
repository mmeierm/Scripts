
<#
.SYNOPSIS
Retrieves the Windows AutoPilot deployment details from WinPE for OSDCloud

Expects "oa3tool.exe" from the Windows ADK (default at "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Licensing\OA30") in the same folder as this script to create the HW Hash
In order to also detect the TPM Module as needed for Self-Deploying Mode, we need the File "PCPKsp.dll" from "C:\Windows\System32" from a Full Windows Installation
 
MIT LICENSE
 
Copyright (c) 2020 Microsoft
 
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 
#>

###############################Connect to Autopilot###############################
# Get NuGet
$provider = Get-PackageProvider NuGet -ErrorAction Ignore
if (-not $provider) {
    Write-Host "Installing provider NuGet"
    Find-PackageProvider -Name NuGet -ForceBootstrap -IncludeDependencies
}

# Get WindowsAutopilotIntune module (and dependencies)
$module = Import-Module WindowsAutopilotIntune -PassThru -ErrorAction Ignore
if (-not $module) {
    Write-Host "Installing module WindowsAutopilotIntune"
    Install-Module WindowsAutopilotIntune -Force -SkipPublisherCheck
}
Import-Module WindowsAutopilotIntune -Scope Global
Connect-MgGraph -UseDeviceCode

###############################Generating Hash###############################

#Create the ConfigFiles for OA3Tool

$inputxml=@' 
<?xml version="1.0"?>
  <Key>
    <ProductKey>XXXXX-XXXXX-XXXXX-XXXXX-XXXXX</ProductKey>
    <ProductKeyID>0000000000000</ProductKeyID>  
    <ProductKeyState>0</ProductKeyState>
  </Key>
'@

$oa3cft=@' 
<OA3>
   <FileBased>
       <InputKeyXMLFile>".\input.XML"</InputKeyXMLFile>
   </FileBased>
   <OutputData>
<AssembledBinaryFile>.\OA3.bin</AssembledBinaryFile>
<ReportedXMLFile>.\OA3.xml</ReportedXMLFile>
   </OutputData>
</OA3>
'@

If(!(Test-Path $PSScriptRoot\input.xml))
{
    New-Item "$PSScriptRoot\input.xml" -ItemType File -Value $inputxml
}
If(!(Test-Path $PSScriptRoot\OA3.cfg))
{
    New-Item "$PSScriptRoot\OA3.cfg" -ItemType File -Value $oa3cft
}

$serial = (Get-WmiObject -Class Win32_BIOS).SerialNumber

# Gather the AutoPilot Hash information
#################Start WinPE TPM Fix###################
If(Test-Path X:\Windows\System32\wpeutil.exe)
{
Copy-Item "$PSScriptRoot\PCPKsp.dll" "X:\Windows\System32\PCPKsp.dll"
#Register PCPKsp
rundll32 X:\Windows\System32\PCPKsp.dll,DllInstall
}
#################End WinPE TPM Fix###################

#Run OA3Tool
start-process "$PSScriptRoot\oa3tool.exe" -workingdirectory $PSScriptRoot -argumentlist "/Report /ConfigFile=$PSScriptRoot\OA3.cfg /NoKeyCheck" -wait


#Read Hash from generated XML File
[xml]$xmlhash = Get-Content -Path "$PSScriptRoot\OA3.xml"
$hash=$xmlhash.Key.HardwareHash


###############################Upload Hash###############################
# Add the devices
$importStart = Get-Date
$imported = @()
$imported = Add-AutopilotImportedDevice -serialNumber $serial -hardwareIdentifier $Hash # -groupTag $_.'Group Tag' -assignedUser $_.'Assigned User'


# Wait until the devices have been imported
$processingCount = 1
while ($processingCount -gt 0)
{
    $current = @()
    $processingCount = 0
    $imported | % {
        $device = Get-AutopilotImportedDevice -id $_.id
        if ($device.state.deviceImportStatus -eq "unknown") {
            $processingCount = $processingCount + 1
        }
        $current += $device
    }
    $deviceCount = $imported.Length
    Write-Host "Waiting for $processingCount of $deviceCount to be imported"
    if ($processingCount -gt 0){
        Start-Sleep 30
    }
}
$importDuration = (Get-Date) - $importStart
$importSeconds = [Math]::Ceiling($importDuration.TotalSeconds)
$successCount = 0
$current | % {
    Write-Host "$($device.serialNumber): $($device.state.deviceImportStatus) $($device.state.deviceErrorCode) $($device.state.deviceErrorName)"
    if ($device.state.deviceImportStatus -eq "complete") {
        $successCount = $successCount + 1
    }
}
Write-Host "$successCount devices imported successfully. Elapsed time to complete import: $importSeconds seconds"
