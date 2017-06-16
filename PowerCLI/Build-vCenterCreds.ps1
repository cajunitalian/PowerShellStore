<#
.SYNOPSIS
When building a vCenter POSH Profile

.DESCRIPTION
Automates the secure credential storage for PowerCLI Module use.  When you build your profile out in Powershell and you want it to auto-connect to vCenter
you need to use secure credentialing for reference.

.AUTHOR
Matthew Dartez, M.S.S.E. // M.S.I.S.
Version: 1.0

.NOTES
If you have multiple vCenters just add to the filepath, if/then statements and New-VICred Functions.  Make sure to differentiate them with unique items, names and paths.

Here's an example Creds reference using what's build below (This is what you'll put inside the profile iteself)

    $logincred = Get-VICredentialStoreItem -Host vcenter01.example.com -File "C:\Users\testuser\Documents\WindowsPowerShell\Credentials\vcenter01.xml"
    Connect-VIServer vcenter01.example.com -User $logincred.User -Password $logincred.Password

#>

#FilePaths for Roaming Credentials if Needed (Roaming Profiles)
$filepathVCENTER01 = "C:\Users\testuser\Documents\WindowsPowerShell\Credentials\vcenter01.xml"

If(Test-Path $filepathVCENTER01)
{
    Write-Host "XML File Exists, Deleting and Recreating" -ForegroundColor Red -BackgroundColor Black
    Remove-Item -Path $filepathVCENTER01 -Verbose
}
else 
{
    Write-Host "$filepathVCENTER01 Doesn't Exist, Proceeding - Profile Requires Item to not Exist for Success to Occur.  Powershell doesn't support overwriting XML Credentials, they need to be deleted and re-created"
}

#Password Setting - Delete when done
$username = Read-Host -Prompt "Please Enter your Username"
$password = Read-Host -Prompt "Please Enter your Password" -AsSecureString

#Commands for Cred Creation - place your password here and then REMOVE it when done.
Write-Host "Creating Credential Stores"
New-VICredentialStoreItem -Host vcenter01.example.com -User $username -Password $password  -File $filepathVCENTER01 -Verbose