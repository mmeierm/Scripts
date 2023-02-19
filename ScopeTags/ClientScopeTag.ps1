If ((Get-Process -Name "CloudExperienceHostBroker" -ErrorAction SilentlyContinue) -and (Get-Process -Name "WWAHost" -ErrorAction SilentlyContinue))
{
#Set ScopeTag
$SerialNumber=(Get-WmiObject -Class win32_bios).SerialNumber
$body = @{
    SN="$SerialNumber"
    Name="$env:computername"
}
$json = $body | ConvertTo-Json

$HTTPResult=Invoke-RestMethod -Method Post -Uri "<Enter Webhook URI here>" -Body $json -ContentType 'application/json'

exit $HTTPResult
}
else
{
#Nothing to do
exit 0
}
