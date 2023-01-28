[CmdletBinding()]
param(
	[Parameter(Mandatory=$true)] [String] $OutputFile = "", 
	[Parameter(Mandatory=$False)] [String] $GroupTag = ""
)

If((Test-Path X:\Windows\System32\wpeutil.exe) -and (Test-Path $PSScriptRoot\PCPKsp.dll))
{
Copy-Item "$PSScriptRoot\PCPKsp.dll" "X:\Windows\System32\PCPKsp.dll"
#Register PCPKsp
rundll32 X:\Windows\System32\PCPKsp.dll,DllInstall
}



#Change Current Diretory so OA3Tool finds the files written in the Config File 
&cd $PSScriptRoot
#Delete old Files if exits
if (Test-Path $PSScriptRoot\OA3.xml) 
{
  Remove-Item $PSScriptRoot\OA3.xml
}

#Get SN from WMI
$serial = (Get-WmiObject -Class Win32_BIOS).SerialNumber

#Run OA3Tool
&$PSScriptRoot\oa3tool.exe /Report /ConfigFile=$PSScriptRoot\OA3.cfg /NoKeyCheck




#Check if Hash was found
If (Test-Path $PSScriptRoot\OA3.xml) 
{

#Read Hash from generated XML File
[xml]$xmlhash = Get-Content -Path "$PSScriptRoot\OA3.xml"
$hash=$xmlhash.Key.HardwareHash

#Delete XML File
del $PSScriptRoot\OA3.xml







#Create CSV if Output File was set
if ($OutputFile -ne "")
	{

# Depending on the format requested, create the necessary object
	# Initialize empty list
$computers = @()
$product=""
if ($GroupTag -ne "")
		{
			# Create a pipeline object
			$c = New-Object psobject -Property @{
				"Device Serial Number" = $serial
				"Windows Product ID" = $product
				"Hardware Hash" = $hash
				"Group Tag" = $GroupTag
			}
		}
		else
		{
			# Create a pipeline object
			$c = New-Object psobject -Property @{
				"Device Serial Number" = $serial
				"Windows Product ID" = $product
				"Hardware Hash" = $hash
			}
		}
$computers += $c


		if ($GroupTag -ne "")
		{
			$computers | Select "Device Serial Number", "Windows Product ID", "Hardware Hash", "Group Tag" | ConvertTo-CSV -NoTypeInformation | % {$_ -replace '"',''} | Out-File $OutputFile
		}
		else
		{
			$computers | Select "Device Serial Number", "Windows Product ID", "Hardware Hash" | ConvertTo-CSV -NoTypeInformation | % {$_ -replace '"',''} | Out-File $OutputFile
		}
	}


}


else
{
write-host "No Hardware Hash found"
exit 1
}

