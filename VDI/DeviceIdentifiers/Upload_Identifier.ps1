#Parameters
#Webhook URL
$uri= "<INSERT WEBHOOK URI HERE>"

#Detect if we are in OOBE
$oobe = Get-process wwahost -ErrorAction SilentlyContinue
$Username = $env:UserName

IF (($Username -Notlike "*DefaultUser*") -and ($($oobe.name) -eq "wwahost"))
{
    #We are in OBBE, get Device Information for the Corporate Identifier
    $Computersytem = Get-WmiObject -Class win32_computersystem
    $Manufactuer= $Computersytem.Manufacturer
    $Model=$Computersytem.Model
    $Serial=(Get-WmiObject -Class win32_bios).SerialNumber

    #Create Request Body
    $bodyTable = @{

            'Manufactuer' = $Manufactuer
            'Model' = $Model
            'Serial' = $Serial
      }
      
    $body = $bodyTable | ConvertTo-Json

    #Upload Identifier

    $Response = Invoke-WebRequest -Uri $uri -Body $body -Method Post -UseBasicParsing

}

else {
    Write-output "Not In OOBE -> exit"
    exit 0
}
