<#
.SYNOPSIS
Retrieves the Windows AutoPilot deployment details from WinPE 

Expects "oa3tool.exe" from the Windows ADK (default at "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Licensing\OA30") in the same folder as this script to create the HW Hash
In order to also detect the TPM Module as needed for Self-Deploying Mode, we need the File "PCPKsp.dll" from "C:\Windows\System32" from a Full Windows Installation
#>

# base parameters
$GroupTag="" #Define if static GroupTag needed
$GroupTagUI = $false
$GroupTagUIList=@()
$GroupTagUIList =@('Tag1','Default','Other')
$WebhookURI="<-------------INSERT WEBHOOK URL HERE--------------->"


Function Start-Command {
    Param([Parameter (Mandatory=$true)]
          [string]$Command, 
          [Parameter (Mandatory=$true)]
          [string]$Arguments)

    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $Command
    $pinfo.RedirectStandardError = $true
    $pinfo.RedirectStandardOutput = $true
    $pinfo.CreateNoWindow = $true
    $pinfo.UseShellExecute = $false
    $pinfo.Arguments = $Arguments
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null
    $p.WaitForExit()
    [pscustomobject]@{
        stdout = $p.StandardOutput.ReadToEnd()
        stderr = $p.StandardError.ReadToEnd()
        ExitCode = $p.ExitCode  
    }
}

#GUI for GroupTag selection
If ($GroupTagUI)
{
    write-host "Starting GroupTag selection..."

[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
[System.Windows.Forms.Application]::EnableVisualStyles();
$objForm = New-Object System.Windows.Forms.Form
$objForm.Backcolor="white"
$objForm.Text = "GroupTag selection"
$objForm.FormBorderStyle = 'Fixed3D'
$objForm.MaximizeBox = $false

$GroupTagCombobox=New-object system.windows.forms.combobox
$GroupTagCombobox.Location = New-Object System.Drawing.Size(10,10)
$GroupTagCombobox.Size = New-Object System.Drawing.Size(220,40)
$GroupTagCombobox.Font = [System.Drawing.Font]::new("Microsoft Sans Serif", 12, [System.Drawing.FontStyle]::Bold)

foreach ($Tag in $GroupTagUIList){
    $GroupTagCombobox.Items.Add($Tag) | Out-Null
    }

$GroupTagBTN=New-Object System.Windows.Forms.Button
$GroupTagBTN.Location = New-Object System.Drawing.Size(10,50)
$GroupTagBTN.Size = New-Object System.Drawing.Size(220,40)
$GroupTagBTN.Text = "Submmit"
$GroupTagBTN.Font = [System.Drawing.Font]::new("Microsoft Sans Serif", 14, [System.Drawing.FontStyle]::Bold)
$GroupTagBTN.DialogResult = "Cancel"


$GroupTagBTN.add_Click({

    $Script:GroupTag=$GroupTagCombobox.SelectedItem  
})

$objForm.Controls.Add($GroupTagCombobox)
$objForm.Controls.Add($GroupTagBTN)
$objForm.Size = New-Object System.Drawing.Size(250,130)


[void] $objForm.ShowDialog()
}


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


If(Test-Path X:\Windows\System32\wpeutil.exe)
{
Copy-Item "$PSScriptRoot\PCPKsp.dll" "X:\Windows\System32\PCPKsp.dll"
#Register PCPKsp
rundll32 X:\Windows\System32\PCPKsp.dll,DllInstall
}
#################End WinPE###################

#Run OA3Tool
&$PSScriptRoot\oa3tool.exe /Report /ConfigFile=$PSScriptRoot\OA3.cfg /NoKeyCheck

#Check if Hash was found
If (Test-Path $PSScriptRoot\OA3.xml) 
{

#Read Hash from generated XML File
[xml]$xmlhash = Get-Content -Path "$PSScriptRoot\OA3.xml"
$hash=$xmlhash.Key.HardwareHash

#Delete XML File
Remove-Item $PSScriptRoot\OA3.xml

$body = @{
    SN="$serial"
    Hash="$hash"
	GroupTag="$GroupTag"
}
$json = $body | ConvertTo-Json

$HTTPResult=Invoke-RestMethod -Method Post -Uri $WebhookURI -Body $json -ContentType 'application/json'
If ($HTTPResult.JobIds)
{
write-output "Started Upload with JobID "$HTTPResult.JobIds""
exit 0
}
else
{
write-output "Upload failed"
exit 1
}
}

else
{
write-host "No Hardware Hash found"
exit 1
}