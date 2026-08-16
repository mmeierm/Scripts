$MaxSize = (Get-PartitionSupportedSize -DriveLetter C).sizeMax
if ((get-partition -driveletter C).size -eq $MaxSize) {
    Write-Output "The drive C is already at its maximum drive size"
    exit
    }

Resize-Partition -DriveLetter C -Size $MaxSize
