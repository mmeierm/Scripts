<#
License: https://creativecommons.org/licenses/by/4.0/
created by Michael Niehaus oofhours.com / https://www.powershellgallery.com/packages/UEFIv2/2.7
modified by Michael Meier mikemdm.de
#>


#UEFI Functions

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
 


$bytes = New-Object Byte[](4)
$bytes[0] = 1
Set-UEFIVariable -Namespace "{616e2ea6-af89-7eb3-f2ef-4e47368a657b}" -VariableName FORCED_NETWORK_FLAG -ByteArray $bytes

