#Region local VMs


###############################VM Folder Inventory###############################
#$VMPath = "C:\VMs"
$VMPath = "D:\"
If (Test-Path $VMPath)
    {
        $VMFolders = (Get-ChildItem $VMPath -Depth 1  | Where-Object {$_.Name -match ".vmx$"}).FullName
    }


###############################VMWare Player Preferences File###############################
$VMiniArray = @()
$VMPreferencesbase = "C:\Users\"
$VMPreferencespath = "AppData\Roaming\VMware\preferences.ini"
$Users = get-childitem $VMPreferencesbase -Depth 0 -Directory | Select-Object -ExpandProperty Name
foreach ($User in $Users)
    {
    $Userprofile = Join-Path $VMPreferencesbase $User
    $VMPreferencesfullpath = Join-Path $Userprofile $VMPreferencespath

    If (Test-Path $VMPreferencesfullpath)
        {
            $Preferencescontent = Get-Content $VMPreferencesfullpath
            $VMs = $Preferencescontent | Where-Object {$_ -like "pref.mruVM?.filename*" -or $_ -like "pref.mruVM?.displayName*"}
            $VMCount = $VMs.Count /2
            for (($i=0); ($i -lt $VMCount); ($i++))
            {
                $VMName = $Preferencescontent | Where-Object {$_ -like "pref.mruVM$i.displayName*"}
                $VMName = $VMName -split ' = ',2
                $VMName = $VMName[1]
				$VMName = $VMName.Replace('"','')

                $VMFolder = $Preferencescontent | Where-Object {$_ -like "pref.mruVM$i.filename*"}
                $VMFolder = $VMFolder -split ' = ',2
                $VMFolder = $VMFolder[1]
				$VMFolder = $VMFolder.Replace('"','')
                
                If ($VMiniArray.vmxpath -contains $VMFolder)
                    {
                    $VMObject = $VMiniArray | Where-Object -Property VMXPath -EQ $VMFolder
                    $VMobject.User = "$($VMobject.User)" + ", $user"
                    }
                    else
                    {
                    $tempvmini = New-Object -TypeName PSObject
		            $tempvmini | Add-Member -MemberType NoteProperty -Name "VMXPath" -Value $VMFolder -Force
		            $tempvmini | Add-Member -MemberType NoteProperty -Name "VMName" -Value $VMName -Force
				    $tempvmini | Add-Member -MemberType NoteProperty -Name "User" -Value $User -Force
                    $tempvmini | Add-Member -MemberType NoteProperty -Name "Type" -Value "VMwarePlayer" -Force
		            $tempvmini | Add-Member -MemberType NoteProperty -Name "VMDKPath" -Value $null -Force
		            $tempvmini | Add-Member -MemberType NoteProperty -Name "VMDKSize" -Value $null -Force
				    $tempvmini | Add-Member -MemberType NoteProperty -Name "VMDKLastModifiedUTC" -Value $null -Force
				    $tempvmini | Add-Member -MemberType NoteProperty -Name "LastBootTimeUTC" -Value $null -Force
                    $VMiniArray += $tempvmini
                    }
            }
        }
    }

###############################VMWare Workstation Inventory File###############################
$VMInventorybase = "C:\Users\"
$VMInventorypath = "AppData\Roaming\VMware\inventory.vmls"
foreach ($User in $Users)
    {
    $Userprofile = Join-Path $VMInventorybase $User
    $VMInventoryfullpath = Join-Path $Userprofile $VMInventorypath

    If (Test-Path $VMInventoryfullpath)
        {
            $Inventorycontent = Get-Content $VMInventoryfullpath
            $VMs = $Inventorycontent | Where-Object {($_ -like "vmlist?.config*" -or $_ -like "vmlist?.displayName*" -or $_ -like "vmlist??.config*" -or $_ -like "vmlist??.displayName*" -or $_ -like "vmlist???.config*" -or $_ -like "vmlist???.displayName*") -and $_ -notmatch '""'}
            $id = foreach ($vm in $vms) {($vm -split '\.',2)[0].replace('vmlist','')}
            $id = $id | Sort-Object -Unique

            $VMCount = $VMs.Count /2
            for (($i=0); ($i -lt $VMCount); ($i++))
            {
                
                $j = $id[$i]

                $VMName = $Inventorycontent | Where-Object {$_ -like "vmlist$j.displayName*"}
                $VMName = $VMName -split ' = ',2
                $VMName = $VMName[1]
				$VMName = $VMName.Replace('"','')

                $VMFolder = $Inventorycontent | Where-Object {$_ -like "vmlist$j.config*"}
                $VMFolder = $VMFolder -split ' = ',2
                $VMFolder = $VMFolder[1]
				$VMFolder = $VMFolder.Replace('"','')
                
                If ($VMiniArray.vmxpath -contains $VMFolder)
                    {
                    $VMObject = $VMiniArray | Where-Object -Property VMXPath -EQ $VMFolder
                    $VMobject.User = "$($VMobject.User)" + ", $user"
                    }
                    else
                    {
                    $tempvmini = New-Object -TypeName PSObject
		            $tempvmini | Add-Member -MemberType NoteProperty -Name "VMXPath" -Value $VMFolder -Force
		            $tempvmini | Add-Member -MemberType NoteProperty -Name "VMName" -Value $VMName -Force
				    $tempvmini | Add-Member -MemberType NoteProperty -Name "User" -Value $User -Force
                    $tempvmini | Add-Member -MemberType NoteProperty -Name "Type" -Value "VMwareWorkstation" -Force
		            $tempvmini | Add-Member -MemberType NoteProperty -Name "VMDKPath" -Value $null -Force
		            $tempvmini | Add-Member -MemberType NoteProperty -Name "VMDKSize" -Value $null -Force
				    $tempvmini | Add-Member -MemberType NoteProperty -Name "VMDKLastModifiedUTC" -Value $null -Force
				    $tempvmini | Add-Member -MemberType NoteProperty -Name "LastBootTimeUTC" -Value $null -Force
                    $VMiniArray += $tempvmini
                    }
            }
        }
    }
###############################Create Array###############################

foreach ($VMFolder in $VMFolders)

{
$VMFolderPath = Split-Path $VMFolder -Parent
$VMDKPath = (Get-ChildItem $VMFolderPath -Depth 0 | Where-Object {$_.Name -match ".vmdk$"}).FullName
$VMDKItem = Get-Item $VMDKPath

$NVRAMPath = (Get-ChildItem $VMFolderPath -Depth 0 | Where-Object {$_.Name -match ".nvram$"}).FullName
$NVRAMItem = Get-Item $NVRAMPath

    If ($VMiniArray.vmxpath -contains $VMFolder)
        {
        $VMObject = $VMiniArray | Where-Object -Property VMXPath -EQ $VMFolder
        If ($VMObject.Count)
            {
            $VMObject[0].VMDKPath = $VMDKPath
            $VMObject[0].VMDKSize = $VMDKItem.Length
            $VMObject[0].VMDKLastModifiedUTC = $VMDKItem.LastWriteTimeUtc.ToString("o")
            $VMObject[0].LastBootTimeUTC = $NVRAMItem.LastWriteTimeUtc.ToString("o")
            }
        else
            {
            $VMObject.VMDKPath = $VMDKPath
            $VMObject.VMDKSize = $VMDKItem.Length
            $VMObject.VMDKLastModifiedUTC = $VMDKItem.LastWriteTimeUtc.ToString("o")
            $VMObject.LastBootTimeUTC = $NVRAMItem.LastWriteTimeUtc.ToString("o")
            }
        }
    else
        {
        $tempvmini = New-Object -TypeName PSObject
		$tempvmini | Add-Member -MemberType NoteProperty -Name "VMXPath" -Value $VMFolder -Force
		$tempvmini | Add-Member -MemberType NoteProperty -Name "VMName" -Value $null -Force
		$tempvmini | Add-Member -MemberType NoteProperty -Name "User" -Value $null -Force
        $tempvmini | Add-Member -MemberType NoteProperty -Name "Type" -Value "VMwareUnknown" -Force
		$tempvmini | Add-Member -MemberType NoteProperty -Name "VMDKPath" -Value $VMDKPath -Force
		$tempvmini | Add-Member -MemberType NoteProperty -Name "VMDKSize" -Value $VMDKItem.Length -Force
		$tempvmini | Add-Member -MemberType NoteProperty -Name "VMDKLastModifiedUTC" -Value $VMDKItem.LastWriteTimeUtc.ToString("o") -Force
		$tempvmini | Add-Member -MemberType NoteProperty -Name "LastBootTimeUTC" -Value $NVRAMItem.LastWriteTimeUtc.ToString("o") -Force
        $VMiniArray += $tempvmini
        }

   }
try
    {
    #try to get the vmdk of VMs outside predefined folders
    $otherVMs=$VMiniArray | where-Object -Property VMDKPath -eq $null
    foreach ($otherVM in $otherVMs)
        {
            $otherVMPath=$otherVM.VMXPath
            $VMFolderPath = Split-Path $otherVMPath -Parent
            If (Test-Path $VMFolderPath)
            {
                $VMDKPath = (Get-ChildItem $VMFolderPath -Depth 0  | Where-Object {$_.Name -match ".vmdk$"}).FullName
                $NVRAMPath = (Get-ChildItem $VMFolderPath -Depth 0 | Where-Object {$_.Name -match ".nvram$"}).FullName
                $NVRAMItem = Get-Item $NVRAMPath
                If ($VMDKPath.Count -gt 1)
                    {
                    $VMDKItem = Get-Item $VMDKPath[0]
                    ($VMiniArray | Where-Object -Property VMXPath -EQ $otherVMPath).VMDKPath = $VMDKPath[0]
                    ($VMiniArray | Where-Object -Property VMXPath -EQ $otherVMPath).VMDKSize = $null
                    ($VMiniArray | Where-Object -Property VMXPath -EQ $otherVMPath).VMDKLastModifiedUTC = $VMDKItem.LastWriteTimeUtc.ToString("o")
                    ($VMiniArray | Where-Object -Property VMXPath -EQ $otherVMPath).LastBootTimeUTC = $NVRAMItem.LastWriteTimeUtc.ToString("o")                    
                    }
                else
                    {
                    $VMDKItem = Get-Item $VMDKPath
                    ($VMiniArray | Where-Object -Property VMXPath -EQ $otherVMPath).VMDKPath = $VMDKPath
                    ($VMiniArray | Where-Object -Property VMXPath -EQ $otherVMPath).VMDKSize = $VMDKItem.Length
                    ($VMiniArray | Where-Object -Property VMXPath -EQ $otherVMPath).VMDKLastModifiedUTC = $VMDKItem.LastWriteTimeUtc.ToString("o")
                    ($VMiniArray | Where-Object -Property VMXPath -EQ $otherVMPath).LastBootTimeUTC = $NVRAMItem.LastWriteTimeUtc.ToString("o")                    
          
                    }
            }
        }

    }
catch
    {
    }
    
###############################Hyper-V VMs###############################

If (Get-command "get-vm")
{
    #Hyper-V is installed
    $HyperVVMs = Get-VM 

    foreach ($HyperVVM in $HyperVVMs)
    {
        $HyperVDiskItem = Get-item $HyperVVM.harddrives.path

        $tempvmini = New-Object -TypeName PSObject
		$tempvmini | Add-Member -MemberType NoteProperty -Name "VMXPath" -Value $HyperVVM.VMId -Force
		$tempvmini | Add-Member -MemberType NoteProperty -Name "VMName" -Value $HyperVVM.VMName -Force
		$tempvmini | Add-Member -MemberType NoteProperty -Name "User" -Value $null -Force
        $tempvmini | Add-Member -MemberType NoteProperty -Name "Type" -Value "Hyper-V" -Force
		$tempvmini | Add-Member -MemberType NoteProperty -Name "VMDKPath" -Value $HyperVVM.harddrives.path -Force
		$tempvmini | Add-Member -MemberType NoteProperty -Name "VMDKSize" -Value $HyperVDiskItem.Length -Force
		$tempvmini | Add-Member -MemberType NoteProperty -Name "VMDKLastModifiedUTC" -Value $HyperVDiskItem.LastWriteTimeUtc.ToString("o") -Force
		$tempvmini | Add-Member -MemberType NoteProperty -Name "LastBootTimeUTC" -Value $HyperVDiskItem.LastWriteTimeUtc.ToString("o") -Force
        $VMiniArray += $tempvmini
    }
}
else
{
    #Hyper-V is not installed
}


[System.Collections.ArrayList]$localVMs = $VMiniArray


#endregion local VMs
