#Hide Filenames
$regkey="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\"
$name="HideFileExt"
$value=0

#Registry Detection Template

If (!(Test-Path $regkey))
{
Write-Output 'RegKey not available - remediate'
Exit 1
}


$check=(Get-ItemProperty -path $regkey -name $name -ErrorAction SilentlyContinue).$name
if ($check -eq $value){
write-output 'setting ok - no remediation required'
Exit 0
}

else {
write-output 'value not ok, no value or could not read - go and remediate'
Exit 1
}
