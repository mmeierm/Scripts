#Parameters

#Webhook URL
$uri= "<INSERT WEBHOOK URL HERE>"

#Taskname
$Taskname = "MikeMDM-CorpIdent"

#Detect if we are in OOBE
$Username = Get-WMIObject -class Win32_ComputerSystem | select username

IF ($Username -match "DefaultUser")
{
    #We are in OBBE, get Device Information for the Corporate Identifier
    $Computersytem = Get-WmiObject -Class win32_computersystem
    $Manufactuer= $Computersytem.Manufacturer
    $Model=$Computersytem.Model
    $Serial=(Get-WmiObject -Class win32_bios).SerialNumber

    #Create Request Body
    $bodyTable = @{

            'Manufactuer' = $Manufactuer -replace ',',''
            'Model' = $Model -replace ',',''
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
