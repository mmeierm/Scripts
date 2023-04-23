write-host "Starting Kiosk Utility..."

[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
[System.Windows.Forms.Application]::EnableVisualStyles();
$objForm = New-Object System.Windows.Forms.Form
$objForm.Backcolor="white"
$objForm.Text = "Kiosk Mode Utility"
#$objForm.Icon="$PSScriptRoot\Icon.ico"
$objForm.Size = New-Object System.Drawing.Size(1000,400)
$objForm.FormBorderStyle = 'Fixed3D'
$objForm.MaximizeBox = $false




############################################################################
$UserGRPBTN = New-Object System.Windows.Forms.Button
$UserGRPBTN.Location = New-Object System.Drawing.Size(20,280)
$UserGRPBTN.Size = New-Object System.Drawing.Size(400,55)
$UserGRPBTN.Text = "Add User to Kiosk Group"
$UserGRPBTN.Name = "UserGRPBTN"
$UserGRPBTN.DialogResult = "None"
$UserGRPBTN.Font = [System.Drawing.Font]::new("Microsoft Sans Serif", 18, [System.Drawing.FontStyle]::Bold)
$UserGRPBTN.Add_Click({

[void][Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')

$title = 'Add User to Group'
$msg   = 'Enter User that should be used for Kiosk Mode (Format: AzureAD\UPN):'

$groupuser = [Microsoft.VisualBasic.Interaction]::InputBox($msg, $title)

Add-LocalgroupMember -member $groupuser -SID "S-1-5-32-555"

})



$KioskURLBTN = New-Object System.Windows.Forms.Button
$KioskURLBTN.Location = New-Object System.Drawing.Size(570,280)
$KioskURLBTN.Size = New-Object System.Drawing.Size(400,55)
$KioskURLBTN.Text = "Set Kiosk Parameter"
$KioskURLBTN.Name = "KioskURLBTN"
$KioskURLBTN.DialogResult = "None"
$KioskURLBTN.Font = [System.Drawing.Font]::new("Microsoft Sans Serif", 18, [System.Drawing.FontStyle]::Bold)
$KioskURLBTN.Add_Click({

    If ($RadioButton1.Checked -eq $true)
    {
        $newURL =$textBox.Text
    }
    elseif ($RadioButton2.Checked -eq $true)
    {
        $newURI=$textBox2.Text
        $newURL = "`"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe`" --kiosk $newURI --nofirstrun"
    }

write-output $newURL
        [System.Environment]::SetEnvironmentVariable('KIOSK_URL',$newURL,'Machine')
        $currentURL=([System.Environment]::GetEnvironmentVariables("Machine")).KIOSK_URL
        If ($currentURL -eq $newURL)
        {
        #Success
        [System.Windows.Forms.MessageBox]::Show("Sucessfully updated Kiosk URL","Kiosk Utility",0)
        }
        else
        {
        #Error
        [System.Windows.Forms.MessageBox]::Show("Failed to update Kiosk URL","Kiosk Utility",0)
        }

})

# Create a group that will contain your radio buttons
    $MyGroupBox = New-Object System.Windows.Forms.GroupBox
    $MyGroupBox.Location = '20,170'
    $MyGroupBox.size = '950,80'
        
    # Create the collection of radio buttons
    $RadioButton1 = New-Object System.Windows.Forms.RadioButton
    $RadioButton1.Location = '10,15'
    $RadioButton1.size = '80,20'
    $RadioButton1.Checked = $true 
    $RadioButton1.Text = "General"

 
    $RadioButton2 = New-Object System.Windows.Forms.RadioButton
    $RadioButton2.Location = '10,40'
    $RadioButton2.size = '80,20'
    $RadioButton2.Checked = $false
    $RadioButton2.Text = "Edge"


        # Add all the GroupBox controls on one line
    $MyGroupBox.Controls.AddRange(@($Radiobutton1,$RadioButton2))

$textBox = New-Object System.Windows.Forms.TextBox
$textBox.Location = New-Object System.Drawing.Point(100,185)
$textBox.Size = New-Object System.Drawing.Size(850,30)

$textBox2 = New-Object System.Windows.Forms.TextBox
$textBox2.Location = New-Object System.Drawing.Point(100,210)
$textBox2.Size = New-Object System.Drawing.Size(850,30)


###########################################################################


$base64ImageString = "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"
$imageBytes = [Convert]::FromBase64String($base64ImageString)
$ms = New-Object IO.MemoryStream($imageBytes, 0, $imageBytes.Length)
$ms.Write($imageBytes, 0, $imageBytes.Length);
$img = [System.Drawing.Image]::FromStream($ms, $true)
$pictureBox = new-object Windows.Forms.PictureBox
$pictureBox.Location = New-Object System.Drawing.Size(0,1)
$pictureBox.Size = New-Object System.Drawing.Size(437,135)
$pictureBox.Dock = [System.Windows.Forms.DockStyle]::Top
$pictureBox.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::CenterImage
#$picturebox.sizemode=1
$pictureBox.Image = $img


$Label1 = New-Object System.Windows.Forms.Label
$Label1.Location = New-Object System.Drawing.Size(20,150)
$Label1.Font = [System.Drawing.Font]::new("Microsoft Sans Serif", 11, [System.Drawing.FontStyle]::Bold)
$Label1.ForeColor = "Black"
$Label1.Text = "Kiosk Parameter:"
$Label1.AutoSize = $True


$objForm.Controls.Add($Label1)
$objForm.controls.add($pictureBox)
$objForm.Controls.Add($KioskURLBTN)
$objForm.controls.add($pictureBoxResult)
$objForm.Controls.Add($textBox)
$objForm.Controls.Add($textBox2)
$objForm.Controls.Add($UserGRPBTN)
$objForm.Controls.Add($MyGroupBox)

If($null -ne $env:Kiosk_URL)
{
    $TextBox.Text=$env:KIOSK_URL
}
else
{
    $TextBox.Text='"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" --kiosk https://mikemdm.de --nofirstrun'
    $TextBox2.Text ="https://mikemdm.de"
}



If($env:KIOSK_URL -like "*msedge.exe*")
{
    $RadioButton2.Checked = $true 
    $RadioButton1.Checked = $false 
    
$Inputstring =$env:KIOSK_URL
$CharArray =$InputString.Split(" ")
$URI=$CharArray | Where-object {$_ -like "http*"}
$TextBox2.Text=$URI

}


[void] $objForm.ShowDialog()
