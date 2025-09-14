[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
[System.Windows.Forms.Application]::EnableVisualStyles()

#Path to DOSBOX Config File
$DOSBOXXPath = "C:\DOSBox-X\dosbox-x.exe"
$ConfigPath="C:\DOSBox-X\dosbox-x.conf"
$ConfigFile = Get-Content $ConfigPath


# Function to get the current DPI scaling factor
function Get-DpiScaling {
    $DPI=Get-ItemProperty -path "HKCU:\Control Panel\Desktop\WindowMetrics" | Select-Object -ExpandProperty AppliedDPI
    return ($DPI / 96.0)
}

# Get the DPI scaling factor
$dpiScaling = Get-DpiScaling


#Get Com Ports

        $mydevs = (Get-PnPDevice | Where-Object{$_.PNPClass -eq "Ports" } | Where-Object{$_.Present -in "True"} | Where-Object{$_.FriendlyName -match "COM"} | Select-Object Name,Description,Manufacturer,PNPClass,Service,Present,Status,DeviceID | Sort-Object Name)

#Create UI

$objForm = New-Object System.Windows.Forms.Form
$objForm.Backcolor="white"
$objForm.Text = "Com Port selection"
#$objForm.Icon="$PSScriptRoot\Icon.ico"
$objForm.FormBorderStyle = 'Fixed3D'
$objForm.MaximizeBox = $false

$Label0 = New-Object System.Windows.Forms.Label
$Label0.Location = New-Object System.Drawing.Point($(20 * $dpiScaling), $(20 * $dpiScaling))
$Label0.Font = [System.Drawing.Font]::new("Microsoft Sans Serif", 12, [System.Drawing.FontStyle]::Regular)
$Label0.ForeColor = "Black"
#$Label0.Text = "Select up to two Serial Ports that will be available as COM1 (and COM2)."
$Label0.Text = "Select your USB Serial Adapter that will be available as COM1 to the App."
$Label0.AutoSize = $True

$Label01 = New-Object System.Windows.Forms.Label
$Label01.Location = New-Object System.Drawing.Point($(20 * $dpiScaling), $(50 * $dpiScaling))
$Label01.Font = [System.Drawing.Font]::new("Microsoft Sans Serif", 12, [System.Drawing.FontStyle]::Regular)
$Label01.ForeColor = "Black"
$Label01.Text = "Leave not used Ports as `"None`" to not redirect them."
$Label01.AutoSize = $True

$Label1 = New-Object System.Windows.Forms.Label
$Label1.Location = New-Object System.Drawing.Point($(20 * $dpiScaling), $(115 * $dpiScaling))
$Label1.Font = [System.Drawing.Font]::new("Microsoft Sans Serif", 12, [System.Drawing.FontStyle]::Bold)
$Label1.ForeColor = "Black"
$Label1.Text = "COM1:"
$Label1.AutoSize = $True

$Label2 = New-Object System.Windows.Forms.Label
$Label2.Location = New-Object System.Drawing.Point($(20 * $dpiScaling), $(150 * $dpiScaling))
$Label2.Font = [System.Drawing.Font]::new("Microsoft Sans Serif", 12, [System.Drawing.FontStyle]::Bold)
$Label2.ForeColor = "Black"
$Label2.Text = "COM2:"
$Label2.AutoSize = $True

$COM1Combobox=New-object system.windows.forms.combobox
$COM1Combobox.Location = New-Object System.Drawing.Point($(190 * $dpiScaling), $(110 * $dpiScaling))
$COM1Combobox.Size = New-Object System.Drawing.Size($(540 * $dpiScaling), $(45 * $dpiScaling))
$COM1Combobox.Items.Add("None") | Out-Null
$COM1Combobox.Selectedindex =$COM1Combobox.FindString('None')
$COM1Combobox.Font = [System.Drawing.Font]::new("Microsoft Sans Serif", 12, [System.Drawing.FontStyle]::Bold)

$COM2Combobox=New-object system.windows.forms.combobox
$COM2Combobox.Location = New-Object System.Drawing.Point($(190 * $dpiScaling), $(145 * $dpiScaling))
$COM2Combobox.Size = New-Object System.Drawing.Size($(540 * $dpiScaling), $(45 * $dpiScaling))
$COM2Combobox.Items.Add("None") | Out-Null
$COM2Combobox.Selectedindex =$COM2Combobox.FindString('None')
$COM2Combobox.Font = [System.Drawing.Font]::new("Microsoft Sans Serif", 12, [System.Drawing.FontStyle]::Bold)

$ControlStartButton=New-Object System.Windows.Forms.Button
$ControlStartButton.Location = New-Object System.Drawing.Point($(20 * $dpiScaling), $(200 * $dpiScaling))
$ControlStartButton.Size = New-Object System.Drawing.Size($(705 * $dpiScaling), $(45 * $dpiScaling))
$ControlStartButton.Text = "OK"
$ControlStartButton.Font = [System.Drawing.Font]::new("Microsoft Sans Serif", 14, [System.Drawing.FontStyle]::Bold)


foreach ($port in $mydevs){

        $COM2Combobox.Items.Add($($port.name)) | Out-Null
        $COM1Combobox.Items.Add($($port.name)) | Out-Null
        
        }


$ControlStartButton.add_Click({
$serial1 = $null
$serial2 = $null

$Port1 = $COM1Combobox.SelectedItem 
 If ($Port1 -ne "None")
 {
        $matches = $null
        $port1 -Match "\((COM\d{1,2})\)" | Out-Null
        $serial1 = "directserial realport:$($Matches[1])"
 }
 else
 {
 $serial1 = "dummy"
 }
      
 $Port2 = $COM2Combobox.SelectedItem 
 If (($Port2 -ne "None") -and ($Port1 -ne $Port2))
 {
        $matches = $null
        $port2 -Match "\((COM\d{1,2})\)" | Out-Null
        $serial2 = "directserial realport:$($Matches[1])"
 }  
 else
 {
 $serial2 = "disabled"
 }

 foreach($line in $ConfigFile)
 {
 If($line -match "serial1       = ")
    {
    $index= $ConfigFile.IndexOf($line)
    $ConfigFile[$index] = "serial1       = $serial1"
    }
 If($line -match "serial2       = ")
    {
    $index= $ConfigFile.IndexOf($line)
    $ConfigFile[$index] = "serial2       = $serial2"
    }
 }

 #Debug Output
 #write-host "serial1       = $serial1"
 #write-host "serial2       = $serial2"


 #Write to ConfigFile
 Set-Content -Value $ConfigFile -Path $ConfigPath
 
 #Start Programm
 
 Start-Process -FilePath $DOSBOXXPath -ArgumentList "-conf $ConfigPath" 
 $objForm.Close()
 
       })


#Call UI


$objForm.Controls.Add($Label0)
$objForm.Controls.Add($Label01)
$objForm.Controls.Add($Label1)
#$objForm.Controls.Add($Label2)
$objForm.controls.add($COM1Combobox)
#$objForm.controls.add($COM2Combobox)
$objForm.controls.add($ControlStartButton)
$objForm.Size = New-Object System.Drawing.Size($(755 * $dpiScaling), $(305 * $dpiScaling))
[void] $objForm.ShowDialog()
