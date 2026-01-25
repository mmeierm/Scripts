Add-Type -AssemblyName PresentationFramework

# Create the WPF window
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Windows 365 USB Ethernet Redirection Tool" Height="200" Width="600" WindowStartupLocation="CenterScreen">
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <TextBlock Grid.Row="0" TextWrapping="Wrap" Margin="0,0,0,10" FontSize="18" TextAlignment="Center">
            This tool let you enable or disable USB Ethernet redirection. 
        </TextBlock>
        <TextBlock Grid.Row="1" TextWrapping="Wrap" Margin="0,0,0,10" FontSize="12" TextAlignment="Center">
            If you enable redirection, all USB Ethernet devices will be redirected to the Windows 365 virtual machine, make sure you are currenlty not connected to the Internet via USB Ethernet adapter.
        </TextBlock>
        <TextBlock Name="StatusTextBlock" Grid.Row="2" TextWrapping="Wrap" Margin="0,0,0,10" FontSize="12" TextAlignment="Center" Foreground="Blue">
            Checking status...
        </TextBlock>
        <StackPanel Grid.Row="3" Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,10,0,0">
            <Button Name="SetKeyButton" Width="100" Margin="5" Content="Enable"/>
            <Button Name="DeleteKeyButton" Width="100" Margin="5" Content="Disable"/>
            <Button Name="CloseButton" Width="100" Margin="5" Content="Cancel"/>
        </StackPanel>
    </Grid>
</Window>
"@

# Load the XAML
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Get UI elements
$SetKeyButton = $window.FindName("SetKeyButton")
$DeleteKeyButton = $window.FindName("DeleteKeyButton")
$CloseButton = $window.FindName("CloseButton")
$StatusTextBlock = $window.FindName("StatusTextBlock")

# Define the registry key path, name, and value
$regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\Client\UsbSelectDeviceByInterfaces"
$keyName = "100"
$keyValue = "{CAC88484-7515-4C03-82E6-71A87ABAC361}"

# Function to update the status text
function Update-Status {
    if ((Test-Path $regPath) -and (Get-ItemProperty -Path $regPath -Name $keyName -ErrorAction SilentlyContinue)) {
        $StatusTextBlock.Text = "Current status: Enabled"
        $StatusTextBlock.Foreground = "Green"
    } else {
        $StatusTextBlock.Text = "Current status: Disabled"
        $StatusTextBlock.Foreground = "Red"
    }
}



# Event handler for setting the registry key
$SetKeyButton.Add_Click({
    try {
        if (-not (Test-Path $regPath)) {
            New-Item -Path $regPath -Force | Out-Null
        }
        Set-ItemProperty -Path $regPath -Name $keyName -Value $keyValue -ErrorAction Stop
        [System.Windows.MessageBox]::Show("Redirection enabled successfully.", "Success", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        Update-Status
    } catch {
        [System.Windows.MessageBox]::Show("Failed to disable Redirection. Error: $_", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    }
    WriteKey
    $NoFormExit = $False
    $window.Close()
})

# Event handler for deleting the registry key
$DeleteKeyButton.Add_Click({
    try {
        if ((Test-Path $regPath) -and ((Get-ItemProperty $regPath).100)) {
            Remove-ItemProperty -Path $regPath -Name $keyName -ErrorAction Stop
            [System.Windows.MessageBox]::Show("Redirection disabled successfully.", "Success", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        } else {
            [System.Windows.MessageBox]::Show("Redirection was already disabled.", "Info", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        }
        Update-Status
    } catch {
        [System.Windows.MessageBox]::Show("Failed to disable Redirection. Error: $_", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    }
    WriteKey
    $NoFormExit = $False
    $window.Close()
})

# Event handler for closing the window
$CloseButton.Add_Click({
    WriteKey
    $NoFormExit = $False
    $window.Close()
})

#Catch clicking of Form CloseBox
$NoFormExit = $True
$Window.Add_Closing({param($Sender,$ExitForm)
  
        $ExitForm.Cancel= $NoFormExit
})

# Update the status when the window is loaded
Update-Status

# Show the window
$window.ShowDialog()
