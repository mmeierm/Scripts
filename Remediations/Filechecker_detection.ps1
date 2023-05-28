<#
.SYNOPSIS
    Detection script for File checker.

.DESCRIPTION
    Microsoft Intune Detection Script.
    The script compares a contained hash value of JAR file with a locally available file. 
    If they match the script exits with exit code 0, if they do not match exit code 1 is returned. 

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
$Log_File = "$ProgData\Filechecker_detection.log"

# Define path to file
$Path_to_Folder = "C:\Windows\Sun\Java\Deployment\"
$Path_to_File = Join-Path $Path_to_Folder "DeploymentRuleSet.jar"

# Hash of current File
# convert to SHA256 hash e.g. with function (Get-FileHash -Algorithm SHA256 $File) or any other tool creating SHA256 hash and supplement it in the script.
$RulesetOrigHash = ""


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

Write_Log -Message_Type "INFO" -Message "Detection script started. Version $ScriptVersion"

# Check if local ruleset file exists
Write_Log -Message_Type "INFO" -Message "Check if file $Path_to_File exists."
If(!(Test-Path $Path_to_File -PathType Leaf))
{
    # File does not exist
    Write_Log -Message_Type "FAILED" -Message "File does not exist. Remediation needed. Returning Exit Code 1."
    Exit 1			
	Break
}
Else 
{
    # File exists. Create hash.
    Write_Log -Message_Type "INFO" -Message "File found. Creating hash and comparing."
    $RulesetLocalHash = Get-FileHash -Algorithm SHA256 $Path_to_File

    If(($RulesetLocalHash.hash -ceq $RulesetOrigHash))
    {
        # Both files equal. No action needed.
	    Write_Log -Message_Type "SUCCESS" -Message "Files are identical. Returning Exit Code 0."	
        Write-Output "Files are identical. Returning Exit Code 0."	
	    Exit 0
        Break		
    }
    Else	
    {
        # Files are different. Remediation needed.
        Write_Log -Message_Type "FAILED" -Message "Files are NOT identical. Remediation needed. Returning Exit Code 1."		
        Write-Output "Files are NOT identical. Remediation needed. Returning Exit Code 1."		
        Exit 1			
	    Break
    }
}