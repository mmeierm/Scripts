$Policyfolder = "$PSScriptRoot\{8B2387F7-5194-4B9C-AEDC-74EB7C5A4774}"
$MoreInformationlink = "https://mikemdm.de"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# Function to get the current DPI scaling factor
function Get-DpiScaling {
    $DPI=Get-ItemProperty -path "HKCU:\Control Panel\Desktop\WindowMetrics" | Select-Object -ExpandProperty AppliedDPI
    return ($DPI / 96.0)
}

# Get the DPI scaling factor
$dpiScaling = Get-DpiScaling

# Create the form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Test Client default security settings"
$form.Size = New-Object System.Drawing.Size($(600 * $dpiScaling), $(400 * $dpiScaling))
$form.BackColor = "white"
$form.MaximizeBox = $false
#$form.Icon = "$PSScriptRoot\Icon.ico"

# Create the Start button
$startButton = New-Object System.Windows.Forms.Button
$startButton.Text = "Apply Settings"
$startButton.Location = New-Object System.Drawing.Point($(10 * $dpiScaling), $(10 * $dpiScaling))
$startButton.Size = New-Object System.Drawing.Size($(120 * $dpiScaling), $(23 * $dpiScaling))
$form.Controls.Add($startButton)

# Create the output text field
$outputTextBox = New-Object System.Windows.Forms.TextBox
$outputTextBox.Location = New-Object System.Drawing.Point($(10 * $dpiScaling), $(100 * $dpiScaling))
$outputTextBox.Size = New-Object System.Drawing.Size($(560 * $dpiScaling), $(200 * $dpiScaling))
$outputTextBox.Multiline = $true
$outputTextBox.ScrollBars = "Vertical"
$form.Controls.Add($outputTextBox)

# Create the multiline sample text field
$instructionTextBox = New-Object System.Windows.Forms.TextBox
$instructionTextBox.Location = New-Object System.Drawing.Point($(10 * $dpiScaling), $(50 * $dpiScaling))
$instructionTextBox.Size = New-Object System.Drawing.Size($(560 * $dpiScaling), $(40 * $dpiScaling))
$instructionTextBox.Font = [System.Drawing.Font]::new("Microsoft Sans Serif", 10 * $dpiScaling)
$instructionTextBox.Multiline = $true
$instructionTextBox.Text = 'Click "Apply Settings" to start the LGPO tool to apply the recommended default security policies.'
$form.Controls.Add($instructionTextBox)

$Label0 = New-Object System.Windows.Forms.LinkLabel
$Label0.Location = New-Object System.Drawing.Point($(10 * $dpiScaling), $(320 * $dpiScaling))
$Label0.Font = [System.Drawing.Font]::new("Microsoft Sans Serif", 10)
$Label0.ForeColor = "Black"
$Label0.Text = "More information"
$Label0.Width = $(550 * $dpiScaling)
$Label0.Height = $(20 * $dpiScaling)
$Label0.Add_Click({
    $Label0.LinkVisited = $true
    Start-Process $MoreInformationlink
})
$form.Controls.Add($Label0)

# Define the Start button click event
$startButton.Add_Click({
    $logname = "$PSScriptRoot\lgpooutput.txt"
    $logerrname = "$PSScriptRoot\lgpoerroutput.txt"
    $process = Start-Process -FilePath "$PSScriptRoot\lgpo.exe" -ArgumentList "/g `"$Policyfolder`"" -NoNewWindow -RedirectStandardOutput $logname -RedirectStandardError $logerrname -Wait
    $outputTextBox.Text = Get-Content -Path $logname -Raw
    $outputTextBox.Text += Get-Content -Path $logerrname -Raw
    Remove-Item $logname -Force
    Remove-Item $logerrname -Force
    $startButton.Visible = $false
    $instructionTextBox.Text = "Check the output of the LGPO Tool to check if it was successful:"
})

# Run the form
[void]$form.ShowDialog()
