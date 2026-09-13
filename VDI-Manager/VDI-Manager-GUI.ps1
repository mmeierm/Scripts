# Present detected VMs as cards enriched with version information.

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$versionJson = Get-Content -Path "C:\ProgramData\VDI-Manager\VDI-Manager-Versions.json" -Raw | ConvertFrom-Json
$vmInventory = Get-Content -Path "C:\ProgramData\VDI-Manager\VDI-Manager-VMs.json" -Raw | ConvertFrom-Json

function Format-VMDate {
    param([object]$Value)

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
        return "Not available"
    }

    try {
        return (Get-Date $Value).ToString("g")
    }
    catch {
        return [string]$Value
    }
}

function Get-ExpiryStyle {
    param([object]$ExpiryDate, [object]$Update)

    if ($ExpiryDate -eq "Unknown VM / Version" -or [string]::IsNullOrWhiteSpace([string]$ExpiryDate)) {
        return [PSCustomObject]@{
            Name = "Unknown"
            BackColor = [System.Drawing.Color]::FromArgb(245, 246, 248)
            AccentColor = [System.Drawing.Color]::FromArgb(108, 117, 125)
        }
    }

    try {
        $expiry = [DateTime]::Parse([string]$ExpiryDate).ToLocalTime()
        if ($expiry -lt (Get-Date)) {
            return [PSCustomObject]@{
                Name = "Expired"
                BackColor = [System.Drawing.Color]::FromArgb(255, 235, 238)
                AccentColor = [System.Drawing.Color]::FromArgb(183, 28, 28)
            }
        }
        if ($expiry -lt (Get-Date).AddDays(60)) {
            return [PSCustomObject]@{
                Name = "Expires soon"
                BackColor = [System.Drawing.Color]::FromArgb(255, 248, 225)
                AccentColor = [System.Drawing.Color]::FromArgb(230, 126, 0)
            }
        }
        if ($Update -ne $null -and $Update -ne "-") {
            return [PSCustomObject]@{
                Name = "Update available"
                BackColor = [System.Drawing.Color]::FromArgb(255, 248, 225)
                AccentColor = [System.Drawing.Color]::FromArgb(230, 126, 0)
            }
        }

        return [PSCustomObject]@{
            Name = "Current"
            BackColor = [System.Drawing.Color]::FromArgb(232, 245, 233)
            AccentColor = [System.Drawing.Color]::FromArgb(46, 125, 50)
        }
    }
    catch {
        return [PSCustomObject]@{
            Name = "Unknown"
            BackColor = [System.Drawing.Color]::FromArgb(255, 248, 225)
            AccentColor = [System.Drawing.Color]::FromArgb(230, 126, 0)
        }
    }
}

function Add-DetailRow {
    param(
        [System.Windows.Forms.TableLayoutPanel]$Table,
        [string]$Name,
        [object]$Value
    )

    $text = if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { "Not available" } else { [string]$Value }
    $row = $Table.RowCount
    $Table.RowCount++
    $Table.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))

    $nameLabel = New-Object System.Windows.Forms.Label
    $nameLabel.Text = $Name
    $nameLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $nameLabel.AutoSize = $true
    $nameLabel.Margin = New-Object System.Windows.Forms.Padding(0, 7, 16, 7)

    $valueLabel = New-Object System.Windows.Forms.Label
    $valueLabel.Text = $text
    $valueLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $valueLabel.AutoSize = $true
    $valueLabel.MaximumSize = New-Object System.Drawing.Size(520, 0)
    $valueLabel.Margin = New-Object System.Windows.Forms.Padding(0, 7, 0, 7)

    $Table.Controls.Add($nameLabel, 0, $row)
    $Table.Controls.Add($valueLabel, 1, $row)
}

function Show-VMDetails {
    param([object]$VM)

    $detailsForm = New-Object System.Windows.Forms.Form
    $detailsForm.Text = "VM details - $($VM.VMName)"
    $detailsForm.Size = New-Object System.Drawing.Size(780, 650)
    $detailsForm.MinimumSize = New-Object System.Drawing.Size(620, 460)
    $detailsForm.StartPosition = "CenterParent"
    $detailsForm.BackColor = [System.Drawing.Color]::White
    $detailsForm.ShowInTaskbar = $false

    $detailsTable = New-Object System.Windows.Forms.TableLayoutPanel
    $detailsTable.AutoSize = $true
    $detailsTable.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
    $detailsTable.ColumnCount = 2
    $detailsTable.RowCount = 0
    $detailsTable.Dock = [System.Windows.Forms.DockStyle]::Top
    $detailsTable.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 175)))
    $detailsTable.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))

    #Remove VMDK related properties from the inventory details
    $vm.InventoryDetails.psobject.Properties.Remove("VMDKSize")
    $vm.InventoryDetails.psobject.Properties.Remove("VMDKPath")
    $vm.InventoryDetails.psobject.Properties.Remove("VMDKLastModifiedUTC")
    $vm.VersionDetails.psobject.Properties.Remove("Alert")
    $vm.VersionDetails.psobject.Properties.Remove("AlertMessage")
    $vm.VersionDetails.psobject.Properties.Remove("Download")

    foreach ($property in $VM.InventoryDetails.PSObject.Properties) {
        $label = switch ($property.Name) {
            "LastBootTimeUTC" { "Last boot time" }
            "VMXPath" { "VM Identifier" }
            default { $property.Name }
        }
        $value = if ($property.Name -match "Time|Date|Expiry") { Format-VMDate $property.Value } else { $property.Value }
        Add-DetailRow -Table $detailsTable -Name $label -Value $value
    }

    if ($VM.VersionDetails) {
        foreach ($property in $VM.VersionDetails.PSObject.Properties) {
            $value = if ($property.Name -match "Time|Date|Expiry") { Format-VMDate $property.Value } else { $property.Value }
            Add-DetailRow -Table $detailsTable -Name $property.Name -Value $value
        }
    }
    else {
        Add-DetailRow -Table $detailsTable -Name "Version metadata" -Value "No matching entry found"
    }

    $scrollPanel = New-Object System.Windows.Forms.Panel
    $scrollPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $scrollPanel.AutoScroll = $true
    $scrollPanel.Padding = New-Object System.Windows.Forms.Padding(24, 18, 24, 18)
    $scrollPanel.Controls.Add($detailsTable)

    $footer = New-Object System.Windows.Forms.FlowLayoutPanel
    $footer.Dock = [System.Windows.Forms.DockStyle]::Bottom
    $footer.Height = 58
    $footer.FlowDirection = [System.Windows.Forms.FlowDirection]::RightToLeft
    $footer.Padding = New-Object System.Windows.Forms.Padding(12)
    $footer.BackColor = [System.Drawing.Color]::FromArgb(245, 246, 248)

    $closeButton = New-Object System.Windows.Forms.Button
    $closeButton.Text = "Close"
    $closeButton.Size = New-Object System.Drawing.Size(90, 32)
    $closeButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $detailsForm.CancelButton = $closeButton
    $footer.Controls.Add($closeButton)

    if ($VM.Update -ne $null -and $VM.Update -ne "-") {
            
        $downloadButton = New-Object System.Windows.Forms.Button
        $downloadButton.Text = "Get update"
        $downloadButton.Size = New-Object System.Drawing.Size(110, 32)
        $downloadButton.Tag = $VM.DownloadURL
        $downloadButton.Add_Click({
            param($sender)
            try {
                Start-Process ([string]$sender.Tag)
            }
            catch {
                [System.Windows.Forms.MessageBox]::Show("Could not open the update link.", "VDI Manager", "OK", "Error") | Out-Null
            }
        })
        $footer.Controls.Add($downloadButton)
    }

    $header = New-Object System.Windows.Forms.Panel
    $header.Dock = [System.Windows.Forms.DockStyle]::Top
    $header.Height = 82
    $header.BackColor = $VM.ExpiryStyle.AccentColor

    $title = New-Object System.Windows.Forms.Label
    $title.Text = $VM.VMName
    $title.Font = New-Object System.Drawing.Font("Segoe UI", 15, [System.Drawing.FontStyle]::Bold)
    $title.ForeColor = [System.Drawing.Color]::White
    $title.AutoEllipsis = $true
    $title.Location = New-Object System.Drawing.Point(24, 15)
    $title.Size = New-Object System.Drawing.Size(690, 34)

    $status = New-Object System.Windows.Forms.Label
    $status.Text = $VM.ExpiryStyle.Name
    $status.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $status.ForeColor = [System.Drawing.Color]::White
    $status.Location = New-Object System.Drawing.Point(26, 51)
    $status.AutoSize = $true

    $header.Controls.AddRange(@($title, $status))
    $detailsForm.Controls.AddRange(@($scrollPanel, $footer, $header))
    $detailsForm.ShowDialog($form) | Out-Null
    $detailsForm.Dispose()
}

$displayArray = @($vmInventory | ForEach-Object {
    $vm = $_
    $versionDetails = $null
    $expiryDate = "Unknown VM / Version"
    $update = $null
    $downloadURL = $null

    if ($vm.VMName) {
        $versionKey = $versionJson.PSObject.Properties | Where-Object { $_.Name -eq $vm.VMName } | Select-Object -First 1
        if ($versionKey) {
            $versionDetails = $versionKey.Value
            $expiryDate = $versionDetails.Expiry
            $update = $versionDetails.ReplacedBy

            if ($update -and $update -ne "-") {
                $replacementKey = $versionJson.PSObject.Properties | Where-Object { $_.Name -eq $update } | Select-Object -First 1
                if ($replacementKey -and $replacementKey.Value.Download -ne "-") {
                    $downloadURL = $replacementKey.Value.Download
                }
            }
        }
    }

    [PSCustomObject]@{
        VMName = $vm.VMName
        Type = $vm.Type
        User = $vm.User
        LastBootTimeUTC = $vm.LastBootTimeUTC
        ExpiryDate = $expiryDate
        Update = $update
        DownloadURL = $downloadURL
        ExpiryStyle = Get-ExpiryStyle $expiryDate $update
        InventoryDetails = $vm
        VersionDetails = $versionDetails
    }
} | Where-Object { $_.VMName })

$form = New-Object System.Windows.Forms.Form
$form.Text = "VDI Manager - VM Overview"
$form.Size = New-Object System.Drawing.Size(1180, 760)
$form.MinimumSize = New-Object System.Drawing.Size(760, 520)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::White
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

$cardPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$cardPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
$cardPanel.AutoScroll = $true
$cardPanel.WrapContents = $true
$cardPanel.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight
$cardPanel.Padding = New-Object System.Windows.Forms.Padding(16, 8, 16, 16)
$cardPanel.BackColor = [System.Drawing.Color]::FromArgb(238, 241, 244)

$openDetails = {
    param($sender)
    if ($sender.Tag) {
        Show-VMDetails -VM $sender.Tag
    }
}

foreach ($vm in $displayArray) {
    $card = New-Object System.Windows.Forms.Panel
    $card.Size = New-Object System.Drawing.Size(350, 210)
    $card.Margin = New-Object System.Windows.Forms.Padding(10)
    $card.BackColor = $vm.ExpiryStyle.BackColor
    $card.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $card.Cursor = [System.Windows.Forms.Cursors]::Hand
    $card.Tag = $vm
    $card.Add_Click($openDetails)

    $accent = New-Object System.Windows.Forms.Panel
    $accent.Location = New-Object System.Drawing.Point(0, 0)
    $accent.Size = New-Object System.Drawing.Size(6, 210)
    $accent.BackColor = $vm.ExpiryStyle.AccentColor
    $accent.Cursor = [System.Windows.Forms.Cursors]::Hand
    $accent.Tag = $vm
    $accent.Add_Click($openDetails)

    $iconBox = New-Object System.Windows.Forms.PictureBox
    $iconBox.Image = [System.Drawing.SystemIcons]::Application.ToBitmap()
    $iconBox.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
    $iconBox.Location = New-Object System.Drawing.Point(22, 20)
    $iconBox.Size = New-Object System.Drawing.Size(38, 38)
    $iconBox.Cursor = [System.Windows.Forms.Cursors]::Hand
    $iconBox.Tag = $vm
    $iconBox.Add_Click($openDetails)

    $nameLabel = New-Object System.Windows.Forms.Label
    $nameLabel.Text = $vm.VMName
    $nameLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $nameLabel.ForeColor = [System.Drawing.Color]::FromArgb(32, 40, 48)
    $nameLabel.AutoEllipsis = $false
    $nameLabel.Location = New-Object System.Drawing.Point(72, 10)
    $nameLabel.Size = New-Object System.Drawing.Size(250, 50)
    $nameLabel.Cursor = [System.Windows.Forms.Cursors]::Hand
    $nameLabel.Tag = $vm
    $nameLabel.Add_Click($openDetails)

    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.Text = $vm.ExpiryStyle.Name.ToUpperInvariant()
    $statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
    $statusLabel.ForeColor = $vm.ExpiryStyle.AccentColor
    $statusLabel.Location = New-Object System.Drawing.Point(22, 70)
    $statusLabel.AutoSize = $true
    $statusLabel.Cursor = [System.Windows.Forms.Cursors]::Hand
    $statusLabel.Tag = $vm
    $statusLabel.Add_Click($openDetails)

    $userText = if ([string]::IsNullOrWhiteSpace([string]$vm.User)) { "Not assigned" } else { [string]$vm.User }
    $userLabel = New-Object System.Windows.Forms.Label
    $userLabel.Text = "User        $userText"
    $userLabel.Location = New-Object System.Drawing.Point(22, 101)
    $userLabel.Size = New-Object System.Drawing.Size(300, 22)
    $userLabel.AutoEllipsis = $true
    $userLabel.Cursor = [System.Windows.Forms.Cursors]::Hand
    $userLabel.Tag = $vm
    $userLabel.Add_Click($openDetails)

    $bootLabel = New-Object System.Windows.Forms.Label
    $bootLabel.Text = "Last boot   $(Format-VMDate $vm.LastBootTimeUTC)"
    $bootLabel.Location = New-Object System.Drawing.Point(22, 130)
    $bootLabel.Size = New-Object System.Drawing.Size(300, 22)
    $bootLabel.AutoEllipsis = $true
    $bootLabel.Cursor = [System.Windows.Forms.Cursors]::Hand
    $bootLabel.Tag = $vm
    $bootLabel.Add_Click($openDetails)

    $expiryLabel = New-Object System.Windows.Forms.Label
    $expiryLabel.Text = "Expiry       $(Format-VMDate $vm.ExpiryDate)"
    $expiryLabel.Location = New-Object System.Drawing.Point(22, 159)
    $expiryLabel.Size = New-Object System.Drawing.Size(300, 22)
    $expiryLabel.AutoEllipsis = $true
    $expiryLabel.Cursor = [System.Windows.Forms.Cursors]::Hand
    $expiryLabel.Tag = $vm
    $expiryLabel.Add_Click($openDetails)

    $card.Controls.AddRange(@($accent, $iconBox, $nameLabel, $statusLabel, $userLabel, $bootLabel, $expiryLabel))
    $cardPanel.Controls.Add($card)
}

$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Dock = [System.Windows.Forms.DockStyle]::Top
$headerPanel.Height = 116
$headerPanel.BackColor = [System.Drawing.Color]::White

$headingLabel = New-Object System.Windows.Forms.Label
$headingLabel.Text = "VDI Manager"
$headingLabel.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$headingLabel.AutoSize = $true
$headingLabel.Location = New-Object System.Drawing.Point(24, 10)
$headingLabel.ForeColor = [System.Drawing.Color]::FromArgb(0, 51, 102)

$instructionLabel = New-Object System.Windows.Forms.Label
$instructionLabel.Text = "Select a virtual machine to view its complete inventory and version details."
$instructionLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$instructionLabel.AutoSize = $true
$instructionLabel.Location = New-Object System.Drawing.Point(27, 60)
$instructionLabel.ForeColor = [System.Drawing.Color]::FromArgb(70, 70, 70)

$summaryLabel = New-Object System.Windows.Forms.Label
$summaryLabel.Text = "$($displayArray.Count) virtual machine(s) found"
$summaryLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$summaryLabel.AutoSize = $true
$summaryLabel.Location = New-Object System.Drawing.Point(27, 90)
$summaryLabel.ForeColor = [System.Drawing.Color]::FromArgb(100, 100, 100)

$headerPanel.Controls.AddRange(@($headingLabel, $instructionLabel, $summaryLabel))
$form.Controls.AddRange(@($cardPanel, $headerPanel))
$form.ShowDialog() | Out-Null
$form.Dispose()

