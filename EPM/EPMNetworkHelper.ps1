#Requires -Version 5.1

<#
.SYNOPSIS
    EPM Network Helper
.DESCRIPTION
    Displays a GUI with all network adapters (as shown in ncpa.cpl) and allows user to select one.
    When selected, opens the Network Connections control panel with the specific adapter selected.
.NOTES
    Requires: PowerShell 5.1 or higher, Windows Forms
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Function to get network adapters with their GUIDs
function Get-NetworkAdaptersWithGUID {
    try {
        # Get network adapters using WMI - this matches what ncpa.cpl shows
        $script:adapters = Get-WmiObject -Class Win32_NetworkAdapter | Where-Object { 
            $_.NetConnectionID -ne $null -and 
            $_.GUID -ne $null
        }
        
        $adapterList = @()
        foreach ($adapter in $script:adapters) {
            # Check if adapter is enabled/disabled
            $isEnabled = $adapter.NetEnabled
            $netConnectionStatus = $adapter.NetConnectionStatus
            
            # Get connection status description
            $statusDescription = if ($adapter.ConfigManagerErrorCode -eq 22) {
                "Disabled"
            } elseif ($netConnectionStatus -eq $null) {
                "Unknown"
            } else {
                switch ($netConnectionStatus) {
                    0 { "Disconnected" }
                    1 { "Connecting" }
                    2 { "Connected" }
                    3 { "Disconnecting" }
                    4 { "Hardware not present" }
                    5 { "Hardware disabled" }
                    6 { "Hardware malfunction" }
                    7 { "Media disconnected" }
                    8 { "Authenticating" }
                    9 { "Authentication succeeded" }
                    10 { "Authentication failed" }
                    11 { "Invalid address" }
                    12 { "Credentials required" }
                    default { "Unknown" }
                }
            }
            
            $adapterInfo = [PSCustomObject]@{
                Name = $adapter.NetConnectionID
                Description = $adapter.Description
                Status = $statusDescription
                GUID = $adapter.GUID
                IsEnabled = $isEnabled
                DisplayText = "$($adapter.NetConnectionID) - $($adapter.Description) ($statusDescription)"
            }
            $adapterList += $adapterInfo
        }
        
        return $adapterList | Sort-Object Name
    }
    catch {
        Write-Error "Failed to retrieve network adapters: $($_.Exception.Message)"
        return @()
    }
}


# Function to enable/disable network adapter
function Set-NetworkAdapterState {
    param(
        [string]$AdapterGUID,
        [bool]$Enable
    )
    
    try {
        $adapter = Get-WmiObject -Class Win32_NetworkAdapter | Where-Object { $_.GUID -eq $AdapterGUID }
        if ($adapter) {
            if ($Enable) {
                $result = $adapter.Enable()
                if ($result.ReturnValue -eq 0) {
                    return $true
                } else {
                    Write-Error "Failed to enable adapter. Return code: $($result.ReturnValue)"
                    return $false
                }
            } else {
                $result = $adapter.Disable()
                if ($result.ReturnValue -eq 0) {
                    return $true
                } else {
                    Write-Error "Failed to disable adapter. Return code: $($result.ReturnValue)"
                    return $false
                }
            }
        } else {
            Write-Error "Adapter not found"
            return $false
        }
    }
    catch {
        Write-Error "Error managing adapter state: $($_.Exception.Message)"
        return $false
    }
}

# Main function to create and show the UI
function Show-NetworkAdapterUI {
    # Get network adapters
    Write-Host "Retrieving network adapters..."
    $script:adapters = Get-NetworkAdaptersWithGUID
    
    if ($script:adapters.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "No network adapters found or unable to retrieve adapter information.",
            "No Adapters Found",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        return
    }
    
    # Create the main form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "EPM Network Helper"
    $form.Size = New-Object System.Drawing.Size(600, 400)
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.MinimumSize = New-Object System.Drawing.Size(500, 300)
    #$form.Icon = "$PSScriptRoot\icon.ico"
    $form.Icon = [System.Drawing.SystemIcons]::Network
    #$form.backcolor = [System.Drawing.Color]::FromArgb(255, 255, 255) # White background
    
    # Create label
    $label = New-Object System.Windows.Forms.Label
    $label.Text = "Select a network adapter to open its properties in Network Connections:"
    $label.Location = New-Object System.Drawing.Point(10, 10)
    $label.Size = New-Object System.Drawing.Size(560, 30)
    $label.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $form.Controls.Add($label)
    
    # Create ListBox for adapters
    $listBox = New-Object System.Windows.Forms.ListBox
    $listBox.Location = New-Object System.Drawing.Point(10, 45)
    $listBox.Size = New-Object System.Drawing.Size(560, 250)
    $listBox.Font = New-Object System.Drawing.Font("Consolas", 9)
    $listBox.SelectionMode = [System.Windows.Forms.SelectionMode]::One
    $listBox.HorizontalScrollbar = $true
    
    # Add adapters to the listbox
    foreach ($adapter in $script:adapters) {
        $item = $listBox.Items.Add($adapter.DisplayText)
    }
    
    # Handle double-click on listbox item
    $listBox.Add_DoubleClick({
        if ($listBox.SelectedIndex -ge 0) {
            $selectedAdapter = $script:adapters[$listBox.SelectedIndex]
            
                # Open the network adapter properties
                start-process -FilePath "::{7007ACC7-3202-11D1-AAD2-00805FC1270E}\::$($selectedAdapter.GUID)"
            
        }
    })
    
    $form.Controls.Add($listBox)
    
    # Create buttons panel
    $buttonPanel = New-Object System.Windows.Forms.Panel
    $buttonPanel.Location = New-Object System.Drawing.Point(10, 310)
    $buttonPanel.Size = New-Object System.Drawing.Size(560, 40)
    $form.Controls.Add($buttonPanel)
    
    # Create Open button
    $openButton = New-Object System.Windows.Forms.Button
    $openButton.Text = "Open Selected Adapter"
    $openButton.Location = New-Object System.Drawing.Point(0, 5)
    $openButton.Size = New-Object System.Drawing.Size(150, 30)
    $openButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $openButton.Enabled = $false
    
    $openButton.Add_Click({
        if ($listBox.SelectedIndex -ge 0) {
            $selectedAdapter = $script:adapters[$listBox.SelectedIndex]
            
                start-process -FilePath "::{7007ACC7-3202-11D1-AAD2-00805FC1270E}\::$($selectedAdapter.GUID)"
            
        }
    })
    
    $buttonPanel.Controls.Add($openButton)
    
    # Create Refresh button
    $refreshButton = New-Object System.Windows.Forms.Button
    $refreshButton.Text = "Refresh List"
    $refreshButton.Location = New-Object System.Drawing.Point(160, 5)
    $refreshButton.Size = New-Object System.Drawing.Size(100, 30)
    $refreshButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    
    $refreshButton.Add_Click({
        Write-Host "Refreshing network adapters list..."
        $listBox.Items.Clear()
        $script:adapters = Get-NetworkAdaptersWithGUID
        
        foreach ($adapter in $script:adapters) {
            $listBox.Items.Add($adapter.DisplayText)
        }
        
        $openButton.Enabled = $false
    })
    
    $buttonPanel.Controls.Add($refreshButton)
    
    # Create Exit button
    $exitButton = New-Object System.Windows.Forms.Button
    $exitButton.Text = "Exit"
    $exitButton.Location = New-Object System.Drawing.Point(470, 5)
    $exitButton.Size = New-Object System.Drawing.Size(80, 30)
    $exitButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $exitButton.Add_Click({ $form.Close() })
    $buttonPanel.Controls.Add($exitButton)
    
    # Handle selection change
    $listBox.Add_SelectedIndexChanged({
        $openButton.Enabled = ($listBox.SelectedIndex -ge 0)
        
        # Change button text based on adapter status
        if ($listBox.SelectedIndex -ge 0) {
            $selectedAdapter = $script:adapters[$listBox.SelectedIndex]
            if ($selectedAdapter.Status -eq "Disabled") {
                $openButton.Text = "Enable Adapter"
            } else {
                $openButton.Text = "Open Selected Adapter"
            }
        }
    })
        
    # Make form resizable
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable
    
    # Handle form resize
    $form.Add_Resize({
        $listBox.Size = New-Object System.Drawing.Size(($form.ClientSize.Width - 20), ($form.ClientSize.Height - 110))
        $buttonPanel.Location = New-Object System.Drawing.Point(10, ($form.ClientSize.Height - 50))
        $buttonPanel.Size = New-Object System.Drawing.Size(($form.ClientSize.Width - 20), 40)
        $exitButton.Location = New-Object System.Drawing.Point(($buttonPanel.Width - 90), 5)
    })
    
    # Show the form
    #Write-Host "Displaying Network Adapter UI..."
    $form.Add_Shown({ $form.Activate() })
    [void]$form.ShowDialog()
}


    Show-NetworkAdapterUI

