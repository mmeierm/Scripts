
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

# base parameters
$GroupTag="" #Define if needed

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

$HTTPResult=Invoke-RestMethod -Method Post -Uri "<-------------INSERT WEBHOOK URL HERE--------------->" -Body $json -ContentType 'application/json'
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
