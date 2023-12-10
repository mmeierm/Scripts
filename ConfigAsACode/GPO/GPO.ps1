import-module grouppolicy
$ExportFolder = "C:\01_DATA\GPO\" #TempFolder where the GPO Exports are cached
If (!(Test-Path $ExportFolder))
{
New-Item -ItemType Directory -Force -Path $ExportFolder -ErrorAction SilentlyContinue
}

If (!(Test-Path "$PSScriptRoot\GPO"))
{
New-Item -ItemType Directory -Force -Path "$PSScriptRoot\GPO" -ErrorAction SilentlyContinue
}

#Export Reports of all GPOs

$GPOs=Get-GPO -ALL -Domain "Playgroundbul.de" #Modify to your Domainname
foreach ($Entry in $GPOs)
    {
    $Name = $entry.Displayname
    $Path = $ExportFolder+$entry.Displayname+'.xml'
    write-output "Generating Report for Policy $Name"

    Get-GPOReport -Name $name -ReportType Xml -Path $Path

    #Removing the Read Time of the export

    $xml = [xml](Get-Content -Path $path)
    $node = $xml.GPO
    $node.ReadTime = ""
    $xml.Save($path)
    #Compare exported


    $fileBackuped = $PSScriptRoot+'\GPO\'+$entry.Displayname+'.xml'

    If (Test-Path $fileBackuped)
        {
            if((Get-FileHash $path).hash  -ne (Get-FileHash $fileBackuped).hash)
                {

                #Backup new Report to Repo
                Copy-Item -path $path -Destination $fileBackuped -force

                #Backup Policy if different from Backup
                $BackupPath=$PSScriptRoot+'\GPOBackup\'+$name
                write-output "Backup $name to $BackupPath"
                If (-Not (Test-Path $BackupPath))
                    {
                    New-Item -ItemType directory -Path $BackupPath 
                    }
                    Backup-GPO -Guid $Entry.id -Path $BackupPath

                }

            Else 
                {
                write-output "Files are the same, nothing to do"
                }
        }
        Else
        {
                #Backup new Report to Repo
                Copy-Item -path $path -Destination $fileBackuped -force

                #Backup Policy if different from Backup
                $BackupPath=$PSScriptRoot+'\GPOBackup\'+$name
                write-output "Backup $name to $BackupPath"
                If (-Not (Test-Path $BackupPath))
                    {
                    New-Item -ItemType directory -Path $BackupPath 
                    }
                    Backup-GPO -Guid $Entry.id -Path $BackupPath
        }
    }
