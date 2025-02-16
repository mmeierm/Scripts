#Parameters

#Webhook URL
$uri= "https://4013c855-7377-4c74-b70e-c8cf5c657389.webhook.dewc.azure-automation.net/webhooks?token=g0I118rkmamQiSwkcP5oivkEBGLR%2bG94ikNOB3jS3Vs%3d"

#Taskname
$Taskname = "MikeMDM-CorpIdent"

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
    $JobId = ($Response.Content | ConvertFrom-Json).JobIds
    If ($JobId)
    {
        #Disable Task
        Get-ScheduledTask $Taskname | Disable-ScheduledTask
        exit 0
    }
    else {
        Write-Output "Upload failed"
        Start-Sleep 30
        Get-ScheduledTask $Taskname | Start-ScheduledTask
        exit 1
    }
}

else {
    Write-output "Not In OOBE -> exit"
    exit 0
}
