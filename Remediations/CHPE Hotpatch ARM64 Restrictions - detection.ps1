$regkey="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
$name="HotPatchRestrictions"
$value=1

#do only modify following secion if required

If (!(Test-Path $regkey))
{
Write-Output 'RegKey not available - remediate'
Exit 1
}


$check=(Get-ItemProperty -path $regkey -name $name -ErrorAction SilentlyContinue).$name
if ($check -eq $value){
write-output 'setting available and ok - exit gracefully'
Exit 0
}

else {
write-output 'setting not ok - remediate'
Exit 1
}
