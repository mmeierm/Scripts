#Define BasePolicy Path
$PathBaseRuleset = "$PSScriptroot\Policies\BasePolicy.xml"
#Define Output Path for WDAC Policy
$OutputFileXML = "$PSScriptroot\Policies\WDACPolicy.xml"
$OutputFileBin = "$PSScriptroot\Policies\WDACPolicy.bin"

#Copy the Base Policy to the Output path to modify it
Copy-Item $PathBaseRuleset $OutputFileXML -force

#Read in all certificates that should be added
$Publishers=(Get-ChildItem *.cer -Recurse).FullName

#Loop through all certificates
foreach($Publisher in $Publishers)
{
    #Check that we are only adding certificates for Applications that are still in use
    If ($Publisher -notcontains "01_Certs\Applications\ARCHIVE\")
    {
        Write-Output "Adding Publisher $Publisher to the Policy"
        Add-SignerRule -FilePath $OutputFileXML -CertificatePath $Publisher -User
    }
    
}

#Convert the Policy to binary format to prepare it for upload to Intune
ConvertFrom-CIPolicy -XmlFilePath $OutputFileXML -BinaryFilePath $OutputFileBin 
