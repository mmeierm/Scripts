#================================================
#   Hardware Check
#================================================
$HWCompatible=$true
$TPMVersion=(Get-WmiObject -Namespace 'root\cimv2\security\microsofttpm' -Query 'Select * from win32_tpm').SpecVersion
$CPU=(Get-WmiObject -class win32_processor)
If ($CPU.Name -like "Intel*")
    {
        #Intel CPU found -> Start Check for needed CPU Gen
        #Write-Output "Intel CPU found -> Start Check for needed CPU Gen"
        If ($CPU.Name -like "Intel(R) Core(TM) i?-[2-7]*")
        {
            $HWCompatible=$false
        }
    }

If ($TPMVersion -like "2.*")
    {
        #TPM 2.0
        #Write-Output "TPM 2.0 Chip found"
    }
else
    {
        #No TPM 2.0
        #Write-Output "No TPM 2.0 Chip found"
        $HWCompatible=$false
    }

#================================================
#   Tenant Lockdown Functions (Part of https://www.powershellgallery.com/packages/UEFIv2/2.7)
#================================================

$definition = @' 
  using System; 
  using System.Runtime.InteropServices; 
  using System.Text; 
    
  public class UEFINative 
  { 
         [DllImport("kernel32.dll", SetLastError = true)] 
         public static extern UInt32 GetFirmwareEnvironmentVariableA(string lpName, string lpGuid, [Out] Byte[] lpBuffer, UInt32 nSize); 
  
         [DllImport("kernel32.dll", SetLastError = true)] 
         public static extern UInt32 SetFirmwareEnvironmentVariableA(string lpName, string lpGuid, Byte[] lpBuffer, UInt32 nSize); 
  
         [DllImport("ntdll.dll", SetLastError = true)] 
         public static extern UInt32 NtEnumerateSystemEnvironmentValuesEx(UInt32 function, [Out] Byte[] lpBuffer, ref UInt32 nSize); 
  } 
'@

$uefiNative = Add-Type $definition -PassThru

# Global constants
$global:UEFIGlobal = "{8BE4DF61-93CA-11D2-AA0D-00E098032B8C}"
$global:UEFIWindows = "{77FA9ABD-0359-4D32-BD60-28F4E78F784B}"
$global:UEFISurface = "{D2E0B9C9-9860-42CF-B360-F906D5E0077A}"
$global:UEFITesting = "{1801FBE3-AEF7-42A8-B1CD-FC4AFAE14716}"
$global:UEFISecurityDatabase = "{d719b2cb-3d3a-4596-a3bc-dad00e67656f}"


# -----------------------------------------------------------------------------
# Get-UEFIVariable
# -----------------------------------------------------------------------------

function Get-UEFIVariable
{

    [cmdletbinding()]  
    Param(
        [Parameter(ParameterSetName='All', Mandatory = $true)]
        [Switch]$All,

        [Parameter(ParameterSetName='Single', Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [String]$Namespace = $global:UEFIGlobal,

        [Parameter(ParameterSetName='Single', Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [String]$VariableName,

        [Parameter(ParameterSetName='Single', Mandatory=$false)]
        [Switch]$AsByteArray = $false
    )

    BEGIN {
        $rc = Set-LHSTokenPrivilege -Privilege SeSystemEnvironmentPrivilege
    }
    PROCESS {
        if ($All) {
            # Get the full variable list
            $VARIABLE_INFORMATION_NAMES = 1
            $size = 1024 * 1024
            $result = New-Object Byte[]($size)
            $rc = $uefiNative[0]::NtEnumerateSystemEnvironmentValuesEx($VARIABLE_INFORMATION_NAMES, $result, [ref] $size)
            $lastError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
            if ($rc -eq 0)
            {
                $currentPos = 0
                while ($true)
                {
                    # Get the offset to the next entry
                    $nextOffset = [System.BitConverter]::ToUInt32($result, $currentPos)
                    if ($nextOffset -eq 0)
                    {
                        break
                    }
    
                    # Get the vendor GUID for the current entry
                    $guidBytes = $result[($currentPos + 4)..($currentPos + 4 + 15)]
                    [Guid] $vendor = [Byte[]]$guidBytes
                    
                    # Get the name of the current entry
                    $name = [System.Text.Encoding]::Unicode.GetString($result[($currentPos + 20)..($currentPos + $nextOffset - 1)])
    
                    # Return a new object to the pipeline
                    New-Object PSObject -Property @{Namespace = $vendor.ToString('B'); VariableName = $name.Replace("`0","") }
    
                    # Advance to the next entry
                    $currentPos = $currentPos + $nextOffset
                }
            }
            else
            {
                Write-Error "Unable to retrieve list of UEFI variables, last error = $lastError."
            }
        }
        else {
            # Get a single variable value
            $size = 1024
            $result = New-Object Byte[]($size)
            $rc = $uefiNative[0]::GetFirmwareEnvironmentVariableA($VariableName, $Namespace, $result, $size)
            $lastError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
            if ($lastError -eq 122)
            {
                # Data area passed wasn't big enough, try larger. Doing 32K all the time is slow, so this speeds it up.
                $size = 32*1024
                $result = New-Object Byte[]($size)
                $rc = $uefiNative[0]::GetFirmwareEnvironmentVariableA($VariableName, $Namespace, $result, $size)
                $lastError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()    
            }
            if ($rc -eq 0)
            {
                Write-Error "Unable to retrieve variable $VariableName from namespace $Namespace, last error = $lastError."
                return ""
            }
            else
            {
                Write-Verbose "Variable $VariableName retrieved with $rc bytes"
                [System.Array]::Resize([ref] $result, $rc)
                if ($AsByteArray)
                {
                    return $result
                }
                else
                {
                    $enc = [System.Text.Encoding]::ASCII
                    return $enc.GetString($result)
                }
            }
        }

    }
    END {
        $rc = Set-LHSTokenPrivilege -Privilege SeSystemEnvironmentPrivilege -Disable
    }
}

# -----------------------------------------------------------------------------
# Set-UEFIVariable
# -----------------------------------------------------------------------------

function Set-UEFIVariable
{
    [cmdletbinding()]  
    Param(
        [Parameter()]
        [String]$Namespace = "{8BE4DF61-93CA-11D2-AA0D-00E098032B8C}",

        [Parameter(Mandatory=$true)]
        [String]$VariableName,

        [Parameter()]
        [String]$Value = "",

        [Parameter()]
        [Byte[]]$ByteArray = $null
    )

    BEGIN {
        $rc = Set-LHSTokenPrivilege -Privilege SeSystemEnvironmentPrivilege
    }
    PROCESS {
        if ($Value -ne "")
        {
            $enc = [System.Text.Encoding]::ASCII
            $bytes = $enc.GetBytes($Value)
            Write-Verbose "Setting variable $VariableName to a string value with $($bytes.Length) characters"
            $rc = $uefiNative[0]::SetFirmwareEnvironmentVariableA($VariableName, $Namespace, $bytes, $bytes.Length)
        }
        else
        {
            Write-Verbose "Setting variable $VariableName to a byte array with $($ByteArray.Length) bytes"
            $rc = $uefiNative[0]::SetFirmwareEnvironmentVariableA($VariableName, $Namespace, $ByteArray, $ByteArray.Length)
        }
        $lastError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        if ($rc -eq 0)
        {
            Write-Error "Unable to set variable $VariableName from namespace $Namespace, last error = $lastError"
        }
    }
    END {
        $rc = Set-LHSTokenPrivilege -Privilege SeSystemEnvironmentPrivilege -Disable
    }

}

function Set-LHSTokenPrivilege
{
   
[cmdletbinding(  
    ConfirmImpact = 'low',
    SupportsShouldProcess = $false
)]  

[OutputType('System.Boolean')]

Param(

    [Parameter(Position=0,Mandatory=$True,ValueFromPipeline=$False,HelpMessage='An Token Privilege.')]
    [ValidateSet(
        "SeAssignPrimaryTokenPrivilege", "SeAuditPrivilege", "SeBackupPrivilege",
        "SeChangeNotifyPrivilege", "SeCreateGlobalPrivilege", "SeCreatePagefilePrivilege",
        "SeCreatePermanentPrivilege", "SeCreateSymbolicLinkPrivilege", "SeCreateTokenPrivilege",
        "SeDebugPrivilege", "SeEnableDelegationPrivilege", "SeImpersonatePrivilege", "SeIncreaseBasePriorityPrivilege",
        "SeIncreaseQuotaPrivilege", "SeIncreaseWorkingSetPrivilege", "SeLoadDriverPrivilege",
        "SeLockMemoryPrivilege", "SeMachineAccountPrivilege", "SeManageVolumePrivilege",
        "SeProfileSingleProcessPrivilege", "SeRelabelPrivilege", "SeRemoteShutdownPrivilege",
        "SeRestorePrivilege", "SeSecurityPrivilege", "SeShutdownPrivilege", "SeSyncAgentPrivilege",
        "SeSystemEnvironmentPrivilege", "SeSystemProfilePrivilege", "SeSystemtimePrivilege",
        "SeTakeOwnershipPrivilege", "SeTcbPrivilege", "SeTimeZonePrivilege", "SeTrustedCredManAccessPrivilege",
        "SeUndockPrivilege", "SeUnsolicitedInputPrivilege")]
    [String]$Privilege,

    [Parameter(Position=1)]
    $ProcessId = $pid,

    [Switch]$Disable
   )

BEGIN {

    Set-StrictMode -Version Latest
    ${CmdletName} = $Pscmdlet.MyInvocation.MyCommand.Name

## Taken from P/Invoke.NET with minor adjustments.

$definition = @' 
  using System; 
  using System.Runtime.InteropServices; 
    
  public class AdjPriv 
  { 
   [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)] 
   internal static extern bool AdjustTokenPrivileges(IntPtr htok, bool disall, ref TokPriv1Luid newst, int len, IntPtr prev, IntPtr relen); 
    
   [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)] 
   internal static extern bool OpenProcessToken(IntPtr h, int acc, ref IntPtr phtok); 
  
   [DllImport("advapi32.dll", SetLastError = true)] 
   internal static extern bool LookupPrivilegeValue(string host, string name, ref long pluid); 
  
   [StructLayout(LayoutKind.Sequential, Pack = 1)] 
   internal struct TokPriv1Luid 
   { 
    public int Count; 
    public long Luid; 
    public int Attr; 
   } 
    
   internal const int SE_PRIVILEGE_ENABLED = 0x00000002; 
   internal const int SE_PRIVILEGE_DISABLED = 0x00000000; 
   internal const int TOKEN_QUERY = 0x00000008; 
   internal const int TOKEN_ADJUST_PRIVILEGES = 0x00000020; 
  
   public static bool EnablePrivilege(long processHandle, string privilege, bool disable) 
   { 
    bool retVal; 
    TokPriv1Luid tp; 
    IntPtr hproc = new IntPtr(processHandle); 
    IntPtr htok = IntPtr.Zero; 
    retVal = OpenProcessToken(hproc, TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, ref htok); 
    tp.Count = 1; 
    tp.Luid = 0; 
    if(disable) 
    { 
     tp.Attr = SE_PRIVILEGE_DISABLED; 
    } 
    else 
    { 
     tp.Attr = SE_PRIVILEGE_ENABLED; 
    } 
    retVal = LookupPrivilegeValue(null, privilege, ref tp.Luid); 
    retVal = AdjustTokenPrivileges(htok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero); 
    return retVal; 
   } 
  } 
'@



} # end BEGIN

PROCESS {

    $processHandle = (Get-Process -id $ProcessId).Handle
    
    $type = Add-Type $definition -PassThru
    $type[0]::EnablePrivilege($processHandle, $Privilege, $Disable)

} # end PROCESS

END { Write-Verbose "Function ${CmdletName} finished." }

} # end Function Set-LHSTokenPrivilege 
 

#================================================
#   Initialize
#================================================
If ($HWCompatible)
{
    #Windows 11 22H2
    $OSName="Windows 11 22H2 x64"
}
else
{
    #Windows 10 22H2
    $OSName="Windows 10 22H2 x64"
}

#================================================
#   Window Functions
#   Minimize Command and PowerShell Windows
#================================================
$Script:showWindowAsync = Add-Type -MemberDefinition @"
[DllImport("user32.dll")]
public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
"@ -Name "Win32ShowWindowAsync" -Namespace Win32Functions -PassThru
function Hide-CmdWindow() {
    $CMDProcess = Get-Process -Name cmd -ErrorAction Ignore
    foreach ($Item in $CMDProcess) {
        $null = $showWindowAsync::ShowWindowAsync((Get-Process -Id $Item.id).MainWindowHandle, 2)
    }
}
function Hide-PowershellWindow() {
    $null = $showWindowAsync::ShowWindowAsync((Get-Process -Id $pid).MainWindowHandle, 2)
}
function Show-PowershellWindow() {
    $null = $showWindowAsync::ShowWindowAsync((Get-Process -Id $pid).MainWindowHandle, 10)
}


#================================================
#   UI
#================================================
write-host "Starting MikeMDM OSDCloudGUI..."

[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
[System.Windows.Forms.Application]::EnableVisualStyles();
$objForm = New-Object System.Windows.Forms.Form
$objForm.Backcolor="white"
$objForm.Text = "MikeMDM OSD powered by OSDCloud"
#$objForm.Icon="$PSScriptRoot\Icon.ico"
$objForm.FormBorderStyle = 'Fixed3D'
$objForm.MaximizeBox = $false

$base64ImageString = "iVBORw0KGgoAAAANSUhEUgAAAjEAAACaCAYAAABYKxnwAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAABO0SURBVHhe7d09a9zYGsDxZ+6nsMFbGG7rZiqPYZuBVK6SIQuxq5DCxZImJJWdQBy7M+myTQhb2QGHiT9AYJqAx9U0aS+4WEPmW8zV0ShZ25E10jlHOi/6/0C74yFRjvVy9Oi8PZ1ZQgAAAALzn+z/AAAAQSGIAQAAQSKIAQAAQSKIAQAAQSKIAQAAQSKIAQAAQSKIAQAAQSKIAQAAQSKIAQAAQSKIAQAAQSKIAQAAQSKIAQAAQSKIAQAAQSKIAQAAQSKIAQAAQSKIAQAAQSKIAQAAQSKIAQAAQSKIAQAAQSKIAQAAQSKIAQAAQSKIAQAAQSKIAQAAQSKIAQAAQSKIAQAAQSKIAQAAQSKIAQAAQSKIAQAAQSKIAQAAQSKIAQAAQSKIAQAAQSKIAQAAQXIbxFydyKDTkU7utiM7ud+rbSAnV9k+KhvLYe4+1TaQ1y/yvp9vg4/TbB95ivdbVN7px0HO38m2N+PsT8WvTcdh/Cbnd8y2zaebud+nm8FxKDy+L14X3IuHydV9N5P9vtc9DgblLVRYJxWXt7h+KObieihkUDf/9a6e66zQgvNW01GCBzqzRPYZAAAgGHQnAQCAIDUaxKgm08OL7AdoUF1WNI2GJ67zFtN9rLrCTLqBvKK6VP44EZ3fJrTjoF9e6tDYBN0Sk/bFl+0TvjiUjuYNfrepnPxRpUJXf95kPE+Eqp4Xg4o6HqoiLnsdVb1G41GpfrClyvVcS50UuvZer9ATdBCz9Oi5HLwalYqqx1/25ODZlixlP9swfrMs22vnsruefbHQkmy9HcjwN94EUiog6U3k+G2F87KyJe/uD2U5soG+1fTkyYnI8GuJx9/VSIZyLE9KX6PxqFI/WLP+JDnaQxmVCDDrqJPCl9SRzw5k7ws1JMoJfEyMqswncrSoWTF5WB69OpC+zYo8eYva+HYs31/2si9KUg/hpMwbrX4IK8kb17Nt6Y6HsrWSfVXS0qN3cvxto9Vva+oB3d36sPABPf57W+R+v6UPypL1g1XqIdyV7b8XnJk66qRYqEDw2xEt1igl+IG9S78PRM5GhU2y069DkZMnSZVmS/IAfqv/FjV/Q2z5TXrxQba1Wwiyt7W3bW6K70l/f09GhYHcWEbJg/L5o/a+65epH6xb7y9sAbJfJ8VkSfr3S7Y0ovWCD2JUy8bztW35cGdlPpYPW13LFfmlXH4yeYtSD6DPrb5Jp5cTeWDSQqAeFJ/KNdvHqvf4WCYFgdz045FM2v6gXFg/1GFRC1AddVJcyrY0AuEHMYnevbvfylVFvrfft1uRX13K5OGqrGY/6lj974PsUztd/u+zdFdNKvHk+D/MPrbVSl8GctcDWj0oRQa/86Asqh/qkrYA3fEQrqVOis68pbHZrkCEKIog5u7BdFMZnYkcP6a6QIwKBkFejJIH5fPK442iVGGwrTWqBSi3u486qSzV0th4VyCCE0cQk1bmOYPp1LiLtRoq8pVV6X66lMvsRx3mLRFhUy1Rk0uT6kl16XVlte0P6dxBkGrM1oQH5U8lB9taltvdV1edFCMnXYEITSRBTCIdTHe9Ms8G396royJXXRmLBlUWUQMuH7T6Aby02pXPJm9ZqqXBsEsvDvNBkDce0Omg6YH0eVD+65f6oQG/dPfVWSfFyUVXIMISTxCTDqa7VpkbzX5ZxGx2zLxPvOVvY2kTv+5bltnssNjcnO3Gscl3q35oxK16otY6KVJG9QTaIKIgRlXmQ5n9WLdlfVdmpzVW5Mn+z9e2qy+6dnUif2515bzq+jLRSSr4t8cy6VVfwXj68c+KiwzGrie7sx/r7STH9XTGsclxo35oyvV6qO46KUpczygWVRDTtN7L79fGI6il4PPSwKvtx4M6eUt+NpTBP7vMTFBWtmQ4rjhWQQWBZ4PqiwzCSyoPU/4905HNp5u536db6xeL9Fea7iHvnKmN8wbLOrNE9hkAACAYtMQAAIAgNRrExJTCP01eqJmBVv84xJVGPqrroRDnLWVwzxQy2K/q+hjEsqCak+Pg5toOrbyoj+ctMdNm0rKrm58L20vqgRnNQ6aKi0Pp1PHAv6W1x9dAOuaj9rEdDdV9rqjrm/ExsMDzICabolhzWnaSsfmqxQkMG1lllgSROuZT2osTPBq7GiVnP+Lp2Gp2p2wQQMOY/2NiclcktYkcM75qd44ZFcDXu8osOXx0LUrwaG7897aISYLUAPRenkt3688a63a0QQADe2tOy06OGU+RY2a+ymxdb/wcXxNpgsfa8vq0pYXMxQKEiE0AQcy8+baetOxqdVNyzHiJHDOJGt/4Ob5maszro1rIJi3p3lbB4IO6u+YQtSCCGFWZ15KWnRwznsqWzifHzPyN33oAz/G1oZ68Pi3r3lbJdLOPgI5AgpikwqghLfv4CzlmvBT7oMYq1Bt/EsDrJxvNwfG1o47B13RvA5UEE8RYb769OpGjb1TkPlKDGrsElz+pAH5i8Y2f42uL7cHXLezevrqUCdnoYSCcICZhs/m2DaP/g6SCy1cH0ie4/NdKXwa2MvlyfO1KB19bmj3Zwu5ttbzF57VV6mFoCyqIsZaWPavIWR/DP2lwyZo9t2TrJVkI4Dm+ttmaYZONU2pVC9l8/A8TK2AirCBGVeY20rKr7MkzMkn7qPdyJkOCy1+t78rs1PwBx/G1b+nRUGbGWdUt1W0BGb/ZkMnJO8b/wEhgQYzPVE6OnNTz6TZwsqBTcUr894Xlff0i7/v5tvl0M/f7dFuw37qOg1o+P//f9LO8QKyK652sxeriUDbk3P+AOk1Jk/N7pNuO7OR+r7aB/PWuxHGwzaC8hXVd4X7dpuzpzBLZZwAAgGDQEgMAAILUaBCjncI/7aqpo8nKYL+qeU0zy7B/xwFluDhvqmm+jiR5JvvVPg4G90whg/06OQ4LuDi+dV1nddEvL3VovZo/vkG3xKgLuXTfokr9XkcF6p2pfgr/tN+z/guw0nkr0lB5/aMqirLjdQyuB1RXpZ5pTZ0UHhVI1h/UVbmPi1krr7omO0387vYEHcRUSYnfmtV5DVZjVWs2NDH9tsp5K9JUef0zn9ZbKikqq/M2q8IqvqwY7qumEnBWuI8LWSyvmgU5U9nFl4MJZAIfE1MyQV7yxt6WBb70F/FrMmeLjcSGLcsxc0vZpKgs6ti0kqv4tqhOMmGt1bYClYBzb7/fyMuRjeTG9svbk91ZOEsxBD+wt0xK/Pa8sRtE5A3nbClz3gq1PsfMPClqcU6lpt4ocUO6im9xS2N7WxHLU10ky2cD+W68Bk8VUxmdNbkAX5n7uEjT5fVP8EHM4pxK6o2924qKXD+Fv4OcLUa5sFqYYybHopxK+tcDzCxqaWxPnaRnPo5LrSNjY4HHSlTqh7VmX46McqM5KK9vwg9iEkU5lZpsGnTLoHvFUc4W7VxYLcwxk6swp1K7u9tcS1sa7+gmaE+dpCEdrL8sw/vfLayCXJV6OdqTg3sN/7vaudEcldczUQQxdw+ma1FTm0H3irMBhhUGQV7HgMgfspxKX3Iela3vbnNMtTTmdhPQ/F8oTQnzXQZny42PhXE3CL7gPi7CoP1UHEFMehHkDKZrTVObQfeKGmD4zdWNUHIQ5HVOy+shFQh+u51Fme42H+R2E9D8X0JSL5zO5Fw2Gp2CrgbBd129HOXex8WcltcjkQQxiV9S4reoqc2ge8X57JVfzlsxZtvctiT9+7eyKNPd5odfuglo/q9CJSv9fn8oy020yDifLZZzHxdhdttP8QQx6WC6axdBWpG34Y09qxh1IvLsRnA7wPDWeSviRXn9M19350cgaHA9wLKsm+BHa0xr6iR77GQIXyx9OXI8CP7mfVzMh/L6IqIg5tYFrxbtaXpkuxPzpletFP5p//Ou8xuhdEXlSXn9o9Z1GGZdFAbXA+y7Xg+1pk4Kj2r1cb8uyvX7uJgf5fVDVEEMmpEuQPVLOvZsa3owXgnF5X0vh3nfp5udJcGBNgmtftCn0gbk/I7p5mPdEVp5y+nMEtlnAACAYNASAwAAgtRoEKOfur6u9N4G+73ST3uvfxwQJv3rTDXN15GIzWS/2tevwT1TyGC/To7DAi6Or/5xqKtuLhZaefW5Ka9/z+q70RIDx6bpEuPlbpgqf9YeVWHG1ZcPOHZxGOg9Vb0OcvvS6qbObBJBDNyqtOpkNmW16sqWhuZTH4sT+gGoYH03XcyujlbGOo3fLMv22nml2X+9l+fJf9wMnNUpb2gIYlpFNfX5NQq98uJ1GitbmluU0A9AVerh3t36M5xZMReHsvHtWCOrdk92x13ZflZDV2oR7fKGhSCmLVR/eWcjiRrKrUPQjLGMKi9eN1/Zcvi12YAiTeh3Nmq2EgKiVmGhS+cMF5FM88TpZu3XYVjegBDEtIHqf/5tKIN//FoETWXznWisOqm6d7p3ZAiujUrot9ZkJQTET70cPAiiq/ZSLj+ZLPOvXr4eNNgVblrecBDERE4NKuskUcJ5yZUgmzOWD1sig9913hN60t/fa7x7p3fv2hLyAMytrEo3++i1q0uZPFyV1exHHUurDf6mFsobCoKYyKnlqWdJ8L/h24qMFyPZ29fP5qsyBDfevZM2CQ9lFEofPgBEjiCmDVTOln8GMvzNl6l2qr92IsePDQacOeneUbOjuoH04QMBCKXFQLUYfbqUy+xHHdPLiTz4b0O/qYXyhoIgpi3S5InupvrdkGbzHUjfsHvLSffOer90plkAxaZfh/J5bTWAwadJoPVwT0baL01TGZ19lu5qU7+paXnDQRDTKuWzpNbH4qj5xkf8KyHNqAB8Nh8XZ9Qi25hsjSrdl6b0xa3selg2GJY3IAQxaFhyc53amiVlc1/lLT0ayizytReAuo3fbMjk5J1nEw4KqAX61rZlufJKw2M57E3k+G3D0521yxsWghhUli7Dn5vOPdnevBcX6d7TWVi5/2ZHNp9u5n6fbqQTcIrzFp/i+iE7b2ohNjmXYaU1otzrvfx+bbFNtXhozu+Ybv/WdSpYc7U+l055Q9OZJbLPAAAAwaAlBgAABKnRIMa/9N4G+zVIe+/fcXCjPcdBv7yqab6OJHkm+9U/b/7x8Tho79egTqrrOquLfnnjqkP90/zxpSUmAuqG1hsjEH+advs4ZmHivAUpzfnWwENRpWbRDACtqVIGH8rrCYKYCKhcQgda+UeyaXiN5fOIwNVIho1OlYQVnLcgqXVkRCO/WmUerMY9/lJh6QlWD/+JICYKau2SiV4uIXUz/By9jkXGf2+L3O83O1USxjhvITLJr1aVeqFzuBr31YkcvaqSsNFxeT1CEBMJlQ1WL5eQyq4qMvxKw+RiYxklFc3zwKaFgvMWJMP8apWlq3G7yait1eLksLw+IYiJhUEuIdUd1d360PqbYZHpxyOZNNG0Das4byGykF+tMoMWbSOqxamrEWS7Kq9fCGIiop9LqCf9/b3W3wzFmmzahj2ctyBZyq9WVdqi3fALnQqy9/b7WkG2i/L6hiAmJgaDvXqPjzW7o1qi6aZt2MF5C1KlQa42qRbt5IWuucSJKjGkQf6oxsvrH4KYqBgM9jLojoqfi6ZtmOO8BUkNcv3mbiaZeqGbNJU4UbU4rZkF2fbLq9Z66QQzhZsgJjbpYC+92Ub63VGRc9S0DUOctyA5n0m20k+umiZe6FSQvScH9wyDbOvlXZXVh8n/Pl3K5fwLrxHEREcN9hK91pi0O4rWmJuyisZF0zYMcN6ClE01djuTLFs/q+4XujTIttHiZLu8asbqA5GHSTCTfeMzgpgILT0ayuyl1jAx2TqdyS4Lgl3DMQkT5y1IK1synO1qDXK1an1XZqc1B8A2/w1b+0pXSO7I8tlAvtf9+1viNojJDlh+anA3+S1U3pL88nQW5OrI+hFzt+I052nagNy/l2xa6QTmTPZbdBw2n27mfp9ub95rHwcTMZXXSQ4bg3ux8Dp78bpwv+91z9uC/WrfNR7WSXXVD4UKj8OO7OR+r7aB/PVO/3rw7rzVdRw8PG9pXZcGkbP6AziLOrNE9hkAACAYdCcBAIAgEcQAAAAL1LCKZrtdCWIAAMAtUzn5oyOHns9WJYgBAAA3XY1kaGUKeL0IYgAAwA3OFx0siSAGAABcM5aR80UHyyGIAQAAP6nM2pOTJ+4XHSyBIAYAAGTG8mFLZPB7GMvdEcQAAIC5i5Hs7Ztl1m4SQQwAAEioxKkTOX4cQkfSHEEMAADIMmsPpB9IK4xCEAMAQOupVpg9OXgWTvJHhSAGAIDWW5Kt05nser643W0EMQAAxODqRAadjnRytx3Zyf1ebQM5ucr2EZjOLJF9BgAACAYtMQAAIEgEMQAABGj6cSCDj9Psp3YiiAEAANVcHErnjxNxHUIRxAAAgErGX/yYjk0QAwAAyrs6kaNXB9L3YDo2QQwAACht+nUo4kmWa4IYAABQkspy3ZXnj/xY15cgBgAAlDL9eCR7+30vWmEUghgAAFDCVEZn4lWWa4IYAACwmMpyvfZctjzKck0QAwAAFsiyXN/zpxVGIYgBAADFVCuMHMsTz7JcE8QAAIBi67syO3W/uN1tBDEAAMTg6kQGnY50crcd2cn9Xm0Def0i7/v55nN+ps4skX0GAAAIBi0xAAAgSAQxAAAgSAQxAAAgSAQxAAAgSAQxAAAgSAQxAAAgSAQxAAAgSAQxAAAgSAQxAAAgSAQxAAAgSAQxAAAgSAQxAAAgSAQxAAAgSAQxAAAgQCL/B/ZVkmH6CoNcAAAAAElFTkSuQmCC"
$imageBytes = [Convert]::FromBase64String($base64ImageString)
$ms = New-Object IO.MemoryStream($imageBytes, 0, $imageBytes.Length)
$ms.Write($imageBytes, 0, $imageBytes.Length);
$img = [System.Drawing.Image]::FromStream($ms, $true)
$pictureBox = new-object Windows.Forms.PictureBox
$pictureBox.Location = New-Object System.Drawing.Size(0,1)
$pictureBox.Size = New-Object System.Drawing.Size(755,150)
$picturebox.sizemode=1
$pictureBox.Image = $img

$Label0 = New-Object System.Windows.Forms.Label
$Label0.Location = New-Object System.Drawing.Size(20,170)
$Label0.Font = [System.Drawing.Font]::new("Microsoft Sans Serif", 18, [System.Drawing.FontStyle]::Bold)
$Label0.ForeColor = "Black"
$Label0.Text = $OSName
$Label0.AutoSize = $True

$Label1 = New-Object System.Windows.Forms.Label
$Label1.Location = New-Object System.Drawing.Size(20,215)
$Label1.Font = [System.Drawing.Font]::new("Microsoft Sans Serif", 12, [System.Drawing.FontStyle]::Bold)
$Label1.ForeColor = "Black"
$Label1.Text = "OS Language"
$Label1.AutoSize = $True

$Label2 = New-Object System.Windows.Forms.Label
$Label2.Location = New-Object System.Drawing.Size(20,250)
$Label2.Font = [System.Drawing.Font]::new("Microsoft Sans Serif", 12, [System.Drawing.FontStyle]::Bold)
$Label2.ForeColor = "Black"
$Label2.Text = "Selected DriverPack"
$Label2.AutoSize = $True

$Label3 = New-Object System.Windows.Forms.Label
$Label3.Location = New-Object System.Drawing.Size(20,350)
$Label3.Font = [System.Drawing.Font]::new("Microsoft Sans Serif", 8, [System.Drawing.FontStyle]::Bold)
$Label3.ForeColor = "Red"
$Label3.Text = "Warning: All Data will be lost"
$Label3.AutoSize = $True


$formMainWindowControlOSLanguageCombobox=New-object system.windows.forms.combobox
$formMainWindowControlOSLanguageCombobox.Location = New-Object System.Drawing.Size(190,210)
$formMainWindowControlOSLanguageCombobox.Size = New-Object System.Drawing.Size(540,45)
$formMainWindowControlOSLanguageCombobox.Items.Add("en-us") | Out-Null
$formMainWindowControlOSLanguageCombobox.Items.Add("de-de") | Out-Null
$formMainWindowControlOSLanguageCombobox.Selectedindex =$formMainWindowControlOSLanguageCombobox.FindString('en-us')
$formMainWindowControlOSLanguageCombobox.Font = [System.Drawing.Font]::new("Microsoft Sans Serif", 12, [System.Drawing.FontStyle]::Bold)

$formMainWindowControlDriverPackCombobox=New-object system.windows.forms.combobox
$formMainWindowControlDriverPackCombobox.Location = New-Object System.Drawing.Size(190,245)
$formMainWindowControlDriverPackCombobox.Size = New-Object System.Drawing.Size(540,45)
$formMainWindowControlDriverPackCombobox.Font = [System.Drawing.Font]::new("Microsoft Sans Serif", 12, [System.Drawing.FontStyle]::Bold)

$formMainWindowControlStartButton=New-Object System.Windows.Forms.Button
$formMainWindowControlStartButton.Location = New-Object System.Drawing.Size(20,300)
$formMainWindowControlStartButton.Size = New-Object System.Drawing.Size(705,45)
$formMainWindowControlStartButton.Text = "StartOSDCloud"
$formMainWindowControlStartButton.Font = [System.Drawing.Font]::new("Microsoft Sans Serif", 14, [System.Drawing.FontStyle]::Bold)



#================================================
#   DriverPack
#================================================
$DriverPack = Get-OSDCloudDriverPack
$DriverPacks = @()
$DriverPacks = Get-OSDCloudDriverPacks
$formMainWindowControlDriverPackCombobox.Items.Add("None") | Out-Null
$formMainWindowControlDriverPackCombobox.Items.Add("Microsoft Update Catalog") | Out-Null

$DriverPacks | ForEach-Object {
    $formMainWindowControlDriverPackCombobox.Items.Add($_.Name) | Out-Null
}



if ($DriverPack) {
    $formMainWindowControlDriverPackCombobox.Selectedindex = $formMainWindowControlDriverPackCombobox.FindString($DriverPack.Name)
}
else
{
	$formMainWindowControlDriverPackCombobox.Selectedindex = $formMainWindowControlDriverPackCombobox.FindString("Microsoft Update Catalog")
}

#================================================
#   StartButton
#================================================
$formMainWindowControlStartButton.add_Click({
$bytes = New-Object Byte[](4)
$bytes[0] = 1
Set-UEFIVariable -Namespace "{616e2ea6-af89-7eb3-f2ef-4e47368a657b}" -VariableName FORCED_NETWORK_FLAG -ByteArray $bytes

    $objForm.Hide()
    
    $OSLanguage = $formMainWindowControlOSLanguageCombobox.SelectedItem  
    $DriverPackName = $formMainWindowControlDriverPackCombobox.Text
    

    #================================================
    #   Global Variables
    #================================================
    $Global:StartOSDCloudGUI = $null
    $Global:StartOSDCloudGUI = [ordered]@{
        LaunchMethod                = 'OSDCloudGUI'
        AutopilotJsonChildItem      = $null
        AutopilotJsonItem           = $null
        AutopilotJsonName           = $null
        AutopilotJsonObject         = $null
        AutopilotOOBEJsonChildItem  = $null
        AutopilotOOBEJsonItem       = $null
        AutopilotOOBEJsonName       = $null
        AutopilotOOBEJsonObject     = $null
        DriverPackName              = $DriverPackName
        ImageFileFullName           = $null
        ImageFileItem               = $null
        ImageFileName               = $null
        MSCatalogDiskDrivers        = $true
        MSCatalogNetDrivers         = $true
        MSCatalogScsiDrivers        = $true
        MSCatalogFirmware           = $false
        OOBEDeployJsonChildItem     = $null
        OOBEDeployJsonItem          = $null
        OOBEDeployJsonName          = $null
        OOBEDeployJsonObject        = $null
        OSBuild                     = $null
        OSEdition                   = 'Pro'
        OSImageIndex                = '8'
        OSLanguage                  = $OSLanguage
        OSLicense                   = 'Volume'
        OSName                      = $OSName
        OSVersion                   = $null
        Restart                     = $true
        ScreenshotCapture           = $false
        SkipAutopilot               = $true
        SkipAutopilotOOBE           = $true
        SkipODT                     = $true
        SkipOOBEDeploy              = $true
        WindowsDefenderUpdate       = $false
        ZTI                         = $true
    }

    #If WU Drivers selected, replace the dummy entry with an empty one
    If ($formMainWindowControlDriverPackCombobox.Text -eq "None")
    {
        $Global:StartOSDCloudGUI.MSCatalogDiskDrivers=$false
        $Global:StartOSDCloudGUI.MSCatalogNetDrivers=$false
        $Global:StartOSDCloudGUI.MSCatalogScsiDrivers=$false
    }

    Start-OSDCloud 
        
})


#================================================
#   Hide Windows
#================================================
Hide-CmdWindow
############################
###### DISPLAY DIALOG ######
############################

$objForm.Controls.Add($Label0)
$objForm.Controls.Add($Label1)
$objForm.Controls.Add($Label2)
$objForm.Controls.Add($Label3)
$objForm.controls.add($pictureBox)
$objForm.controls.add($formMainWindowControlOSLanguageCombobox)
$objForm.controls.add($formMainWindowControlDriverPackCombobox)
$objForm.controls.add($formMainWindowControlStartButton)
$objForm.Size = New-Object System.Drawing.Size(755,405)


[void] $objForm.ShowDialog()

