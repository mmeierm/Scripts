write-host "Starting Launcher..."

[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
[System.Windows.Forms.Application]::EnableVisualStyles();
$objForm = New-Object System.Windows.Forms.Form
$objForm.Backcolor="white"
$objForm.Text = "MikeMDM OSD powered by OSDCloud"
#$objForm.Icon="$PSScriptRoot\Icon.ico"
$objForm.FormBorderStyle = 'Fixed3D'
$objForm.MaximizeBox = $false
$global:Expert=1

###########################################################################
$name=$env:COMPUTERNAME
$Manufacrurer=(Get-WmiObject -Class win32_computersystem).Manufacturer
If ($Manufacrurer -notlike "*Lenovo*")
{
$Model=(Get-WmiObject -Class win32_computersystem).Model
}
else
{
$Model=(Get-WmiObject -Class win32_computersystemproduct).Version
}


############################################################################

$AutopilotBTN = New-Object System.Windows.Forms.Button
# Die nächsten beiden Zeilen legen die Position und die Größe des Buttons fest
$AutopilotBTN.Location = New-Object System.Drawing.Size(20,250)
$AutopilotBTN.Size = New-Object System.Drawing.Size(500,55)
$AutopilotBTN.Text = "Upload Device to Autopilot"
$AutopilotBTN.Name = "AutopilotBTN"
$AutopilotBTN.DialogResult = "None"
$AutopilotBTN.Font = [System.Drawing.Font]::new("Microsoft Sans Serif", 18, [System.Drawing.FontStyle]::Bold)
#Die folgende Zeile ordnet dem Click-Event die Schließen-Funktion für das Formular zu
$AutopilotBTN.Add_Click({


#Autopilot Update

start-process powershell -workingdirectory "X:\Autopilot" -argumentlist "X:\Autopilot\Autopilot.ps1"


})

$OSDCloudBTN = New-Object System.Windows.Forms.Button
# Die nächsten beiden Zeilen legen die Position und die Größe des Buttons fest
$OSDCloudBTN.Location = New-Object System.Drawing.Size(20,300)
$OSDCloudBTN.Size = New-Object System.Drawing.Size(500,55)
$OSDCloudBTN.Text = "Start-OSDCloud"
$OSDCloudBTN.Name = "OSDCloudBTN"
$OSDCloudBTN.DialogResult = "Cancel"
$OSDCloudBTN.Font = [System.Drawing.Font]::new("Microsoft Sans Serif", 18, [System.Drawing.FontStyle]::Bold)
#Die folgende Zeile ordnet dem Click-Event die Schließen-Funktion für das Formular zu
$OSDCloudBTN.Add_Click({
    start-process powershell -argumentlist "$PSScriptRoot\MikeMDMOSDCloudGUI.ps1"

#Disabled out the confirmation message
<#
$InfoForm = New-Object System.Windows.Forms.Form
$InfoForm.Backcolor="white"
$InfoForm.Text = "Information"
#$InfoForm.Icon="$PSScriptRoot\Icon.ico"
$InfoForm.FormBorderStyle = 'Fixed3D'
$InfoForm.MaximizeBox = $false

$InfoLabel0 = New-Object System.Windows.Forms.Label
$InfoLabel0.Location = New-Object System.Drawing.Size(20,20)
$InfoLabel0.Font = [System.Drawing.Font]::new("Microsoft Sans Serif", 11, [System.Drawing.FontStyle]::Bold)
$InfoLabel0.ForeColor = "Black"
$InfoLabel0.Text = "You don't need to deploy an OS, if the device is already installed"
$InfoLabel0.AutoSize = $True

$InfoLabel1 = New-Object System.Windows.Forms.Label
$InfoLabel1.Location = New-Object System.Drawing.Size(20,40)
$InfoLabel1.Font = [System.Drawing.Font]::new("Microsoft Sans Serif", 11, [System.Drawing.FontStyle]::Bold)
$InfoLabel1.ForeColor = "Black"
$InfoLabel1.Text = "with an up-to-date Windows 11 operating system image."
$InfoLabel1.AutoSize = $True

$InfoLabel2 = New-Object System.Windows.Forms.Label
$InfoLabel2.Location = New-Object System.Drawing.Size(20,65)
$InfoLabel2.Font = [System.Drawing.Font]::new("Microsoft Sans Serif", 9, [System.Drawing.FontStyle]::Bold)
$InfoLabel2.ForeColor = "Black"
$InfoLabel2.Text = "Please only install a approved Version of Windows 11"
$InfoLabel2.AutoSize = $True


$ContinueBTN= New-Object System.Windows.Forms.Button
# Die nächsten beiden Zeilen legen die Position und die Größe des Buttons fest
$ContinueBTN.Location = New-Object System.Drawing.Size(30,100)
$ContinueBTN.Size = New-Object System.Drawing.Size(150,45)
$ContinueBTN.Text = "Continue"
$ContinueBTN.Name = "ContinueBTN"
$ContinueBTN.DialogResult = "Cancel"
$ContinueBTN.Font = [System.Drawing.Font]::new("Microsoft Sans Serif", 18, [System.Drawing.FontStyle]::Bold)
#Die folgende Zeile ordnet dem Click-Event die Schließen-Funktion für das Formular zu
$ContinueBTN.Add_Click({

#OSD Cloud
#start-process powershell -argumentlist "-NoL -W Mi -C Start-OSDCloudGUI -Brand 'MikeMDM OSD powered by OSDCloud'"
#MikeMDM OSD Cloud
start-process powershell -argumentlist "$PSScriptRoot\MikeMDMOSDCloudGUI.ps1"
})

$CancelBTN= New-Object System.Windows.Forms.Button
# Die nächsten beiden Zeilen legen die Position und die Größe des Buttons fest
$CancelBTN.Location = New-Object System.Drawing.Size(300,100)
$CancelBTN.Size = New-Object System.Drawing.Size(150,45)
$CancelBTN.Text = "Cancel"
$CancelBTN.Name = "CancelBTN"
$CancelBTN.DialogResult = "Cancel"
$CancelBTN.Font = [System.Drawing.Font]::new("Microsoft Sans Serif", 18, [System.Drawing.FontStyle]::Bold)
#Die folgende Zeile ordnet dem Click-Event die Schließen-Funktion für das Formular zu
$CancelBTN.Add_Click({
})

$InfoForm.Controls.Add($InfoLabel0)
$InfoForm.Controls.Add($InfoLabel1)
#$InfoForm.Controls.Add($InfoLabel2)
$InfoForm.Controls.Add($ContinueBTN)
$InfoForm.Controls.Add($CancelBTN)
$InfoForm.Size = New-Object System.Drawing.Size(500,200)


[void] $InfoForm.ShowDialog()
#>

})

###########################################################################


$base64ImageString = "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"

$imageBytes = [Convert]::FromBase64String($base64ImageString)
$ms = New-Object IO.MemoryStream($imageBytes, 0, $imageBytes.Length)
$ms.Write($imageBytes, 0, $imageBytes.Length);
$img = [System.Drawing.Image]::FromStream($ms, $true)
$pictureBox = new-object Windows.Forms.PictureBox
$pictureBox.Location = New-Object System.Drawing.Size(0,1)
$pictureBox.Size = New-Object System.Drawing.Size(515,150)
$picturebox.sizemode=1
$pictureBox.Image = $img

$Label0 = New-Object System.Windows.Forms.Label
$Label0.Location = New-Object System.Drawing.Size(20,170)
$Label0.Font = [System.Drawing.Font]::new("Microsoft Sans Serif", 18, [System.Drawing.FontStyle]::Bold)
$Label0.ForeColor = "Black"
$Label0.Text = "OSD powered by OSDCloud"
$Label0.AutoSize = $True

$Label1 = New-Object System.Windows.Forms.Label
$Label1.Location = New-Object System.Drawing.Size(20,210)
$Label1.Font = [System.Drawing.Font]::new("Microsoft Sans Serif", 11, [System.Drawing.FontStyle]::Bold)
$Label1.ForeColor = "Black"
$Label1.Text = "$Manufacrurer $Model"
$Label1.AutoSize = $True

$Label2 = New-Object System.Windows.Forms.Label
$Label2.Location = New-Object System.Drawing.Size(440,360)
$Label2.Font = [System.Drawing.Font]::new("Microsoft Sans Serif", 8, [System.Drawing.FontStyle]::Bold)
$Label2.ForeColor = "Black"
$Label2.Text = "USB Version 0.3"
$Label2.AutoSize = $True
$Label2.Add_Click({
$global:Expert=$global:Expert + 1
If($global:Expert -ge '15')
{
    start-process powershell -argumentlist "-NoL -W Mi -C Start-OSDCloudGUI -Brand 'MikeMDM OSD powered by OSDCloud'"
}
})


$objForm.Controls.Add($Label0)
$objForm.Controls.Add($Label1)
$objForm.Controls.Add($Label2)
$objForm.controls.add($pictureBox)
$objForm.Controls.Add($OSDCloudBTN)
$objForm.Controls.Add($AutopilotBTN)
$objForm.controls.add($pictureBoxResult)
$objForm.Size = New-Object System.Drawing.Size(555,415)


[void] $objForm.ShowDialog()

