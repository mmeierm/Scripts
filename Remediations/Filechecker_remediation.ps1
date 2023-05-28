<#
.SYNOPSIS
    Remediation script for File checker.

.DESCRIPTION
    Microsoft Intune Remediation Script.
    The script converts a contained base64 encoded file and write it locally. 
    If creation was possible the script exits with exit code 0, if not exit code 1 is returned. 

    This script is provided "AS IS" with no warranties

.INPUTS
    None.

.OUTPUTS
    Int16. It returns a integer exit code.

#>

# Define Variables
$ScriptVersion = "1.0"

# Save log file to C:\ProgramData\
$ProgData = $env:PROGRAMDATA
$Log_File = "$ProgData\Filechecker_remediation.log"

# Define path to file. Split definition is needed!
$Path_to_Folder = "C:\Windows\Sun\Java\Deployment\"
$Path_to_File = Join-Path $Path_to_Folder "DeploymentRuleSet.jar"

# Base64 coded File
# convert to Base64 (raw file) with function $variable = [Convert]::ToBase64String([IO.File]::ReadAllBytes($FilePath)) and supplement it in the script.

$RulesetBase64 = ""


# Define Functions
Function Write_Log
	{
		param(
		$Message_Type,	
		$Message
		)
		
		$LogDate = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)		
		Add-Content $Log_File  "$LogDate - $Message_Type : $Message"		
	}

# Main code
	
If(!(test-path $Log_File -PathType Leaf))
{
    $nooutput = new-item $Log_File -ItemType file -force
}
Else
{
    Add-Content $Log_File ""
}

Write_Log -Message_Type "INFO" -Message "Remediation script started. Version $ScriptVersion"

#Check if path exists, if not create it
Write_Log -Message_Type "INFO" -Message "Check if path $Path_to_Folder exists, if not create it."

if(!(test-path $Path_to_Folder))
{
    Write_Log -Message_Type "INFO" -Message "Path not found. Creating $Path_to_Folder"
    try
    {
        #Try to create path
        $nooutput = new-item $Path_to_Folder -ItemType Directory -force
    }
    catch
    {
        #Something went wrong
        Write_Log -Message_Type "FAILED" -Message "Creation of path failed. "+[System.SystemException] +" Returning Exit Code 1."
        Exit 1
        Break           
    }
}

#Convert Base64 to Byte array
Write_Log -Message_Type "INFO" -Message "Convert Base64 to Byte array."
[byte[]]$RulesetBytes = [convert]::FromBase64String($RulesetBase64)

Write_Log -Message_Type "INFO" -Message "Writing $Path_to_File"
try
{
    #Try to write Byte array to file
    [System.IO.File]::WriteAllBytes($Path_to_File,$RulesetBytes)
}
catch
{
    #Something went wrong
    Write_Log -Message_Type "FAILED" -Message "Creation of file failed. "+[System.SystemException] +" Returning Exit Code 1."
    Write-Output "Creation of file failed. "+[System.SystemException] +" Returning Exit Code 1."
    Exit 1
    Break
}

Write_Log -Message_Type "SUCCESS" -Message "File created. Returning Exit Code 0."
Write-Output "File created. Returning Exit Code 0."
Exit 0