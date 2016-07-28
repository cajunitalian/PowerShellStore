<#
.Script for use with vSS builds on new/old deployments, Datastore Construction, etc
-Matthew Dartez

Version: 0.5 - DRAFT // Not For Release

#>

#############################
# Installing Functions      #
#############################

Function Unmount-Datastore {
	[CmdletBinding()]
	Param (
		[Parameter(ValueFromPipeline=$true)]
		$Datastore
	)
	Process {
		if (-not $Datastore) {
			Write-Host "No Datastore defined as input"
			Exit
		}
		Foreach ($ds in $Datastore) {
			$hostviewDSDiskName = $ds.ExtensionData.Info.vmfs.extent[0].Diskname
			if ($ds.ExtensionData.Host) {
				$attachedHosts = $ds.ExtensionData.Host
				Foreach ($VMHost in $attachedHosts) {
					$hostview = Get-View $VMHost.Key
					$StorageSys = Get-View $HostView.ConfigManager.StorageSystem
					Write-Host "Unmounting VMFS Datastore $($DS.Name) from host $($hostview.Name)..."
					$StorageSys.UnmountVmfsVolume($DS.ExtensionData.Info.vmfs.uuid);
				}
			}
		}
	}
}

################################
# Building Transcript/Log Dir  #
################################

Write-Host "##############################################" -ForegroundColor Cyan -BackgroundColor Black
Write-Host "Building Log Directory and Starting Transcript" -ForegroundColor Cyan -BackgroundColor Black
Write-Host "##############################################" -ForegroundColor Cyan -BackgroundColor Black

if (-Not (Test-Path C:\TEMP\BranchAutomation\)) {
    Write-Host ""
    Write-Host "Log Folder Doesn't Exist, creating a Log Folder under C:\TEMP\BranchAutomation\" -ForegroundColor Red -BackgroundColor Black
    Write-Host ""
    New-Item -ItemType Directory -Force -Path C:\TEMP\BranchAutomation
} 
else
{
Write-Host ""
Write-Host "Log Folder Exists, Proceeding" -ForegroundColor Cyan -BackgroundColor Black
Write-Host ""
Start-Sleep -Seconds 2
}

$LogDirectory = "C:\TEMP\BranchAutomation"
Start-Transcript -Path $LogDirectory\AutomationLog.txt

#############################
# Begin vSphere Automation  #
#############################

#Module Checking
#Check if AD Module is already installed
	$checkAD = Get-Module -Name ActiveDirectory
	If ($checkAD.Installed -ne "True") {
	#Install/Enable AD Module
	Write-Host "ActiveDirectory PowerShell Installing..."
	Import-Module ActiveDirectory
	}
#Check if VMware PowerCLI Is installed
	if ( (Get-PSSnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue) -eq $null )
	{
	Write-Host "PowerCLI Installing..."
    Add-PsSnapin VMware.VimAutomation.Core
	}

#Disconnecting vCenter Instances if needed
Disconnect-VIServer * -Force -Confirm:$false

# Establish the 3 Letter Branch Code
Write-Host "When Prompted, please type the 3-Letter Location EX: Dallas = DAL, Salt Lake City = SLC" -ForegroundColor Cyan -BackgroundColor Black
    Start-Sleep -Seconds 2
	$DatacenterLocation = Read-Host -Prompt "Please Type 3 Letter Location Code for example Dallas would be 'DAL' "

# Connection to vCenter - make sure you put in the IP Address/Hostname in the variable
Write-Host "Collect ESXi Information - Please input ESXi Server IP Address" -ForegroundColor Cyan -BackgroundColor Black
    Start-Sleep -Seconds 4
	$VMHost = Read-Host -Prompt "Please provide the ESXi IP Address"
	<#
	Commented out Initial Creds - If user is getting an error it's because they changed the password from "vmware123" as part of the automated USB Installation
	$InitialCreds = Get-Credential -Message "Please Enter Credentials for the ESXi Host (root/password)"
	Connect-VIServer -Server $VMHost -Credential $InitialCreds
	#>
	Write-Host "Connecting to ESXi Server"
	if ((Test-Connection $VMHost -Quiet) -eq $true) {
		Write-Host "ESXi Host Found - Proceeding with Connection" -ForegroundColor Cyan -BackgroundColor Black
		}
		else 
		{
		Write-Host ""
		Write-Host "ESXi Host Not Found, Please Verify that the Host is Online and Rerun the script" -ForegroundColor Red -BackgroundColor White
		Write-Host ""
		Write-Host "Stopping Script and returning to C:\" -ForegroundColor Red -BackgroundColor White
		Write-Host ""
		return
		}

#Connecting vCenter if Test-Connection Completes
Connect-VIServer $VMhost -User root -Password vmware123
	Write-Host "When Prompted, please enter Credentials for the Branch vCenter" -ForegroundColor Cyan -BackgroundColor Black
    Start-Sleep -Seconds 4
    $CredentialBranchVC = Get-Credential -Message "Please Enter your Branch vCenter Credentials"
	#Testing for Branch Connections
	if ((Test-Connection branchvc01.ad.he-equipment.com -Quiet) -eq $true) {
		Write-Host "Branch vCenter is Reachable - Proceeding with Connection" -ForegroundColor Cyan -BackgroundColor Black
		}
		else 
		{
		Write-Host ""
		Write-Host "Branch vCenter Not Found, Please Verify that the server is Online and Rerun the script" -ForegroundColor Red -BackgroundColor White
		Write-Host ""
		Write-Host "Stopping Script and returning to C:\" -ForegroundColor Red -BackgroundColor White
		Write-Host ""
		return
		}

##############################################
### USB Storage Operations                 ###
##############################################

#ISO Movement for Storage
Write-Host "Testing for USB Stick Access, Will cancel if not Found" -ForegroundColor Cyan -BackgroundColor Black
	Start-Sleep -Seconds 2

# Test Path for USB Drive
If (-not (Get-Datastore USB-Stick))
{
#Don't do something
Write-Host "#########################################################################################################################" -ForegroundColor White -BackgroundColor Red
Write-Host "USB Drive is Not Available Please SSH to host and confirm that drive is available and present in /vmfs/volumes/USB-Stick." -ForegroundColor White -BackgroundColor Red
Write-Host "Also Check vSphere if USB is avaiable on host. Make sure the name says USB-Stick exactly.  Contact Engineering if needed." -ForegroundColor White -BackgroundColor Red
Write-Host "#########################################################################################################################" -ForegroundColor White -BackgroundColor Red
Start-Sleep -Seconds 2
Disconnect-VIServer * -Force -Confirm:$false
return
}
else
{
#Do Something
Write-Host "USB-Stick has been Found, Proceeding with Script Automation" -ForegroundColor Cyan -BackgroundColor Black
Start-Sleep -Seconds 2
}

# Build Variable for USB Drive
$datastoreUSB = Get-Datastore "USB-Stick"

# Creating the PSDrive based on the variable.
New-PSDrive -Location $datastoreUSB -Name USB -PSProvider VimDatastore -Root "\"

#Build First Datastore
Write-Host "Making Changes to initial Datastores" -ForegroundColor Cyan -BackgroundColor Black
    Start-Sleep -Seconds 2
$SuffixDS = "-SSD"
$SSD_DSName = $DatacenterLocation + $SuffixDS
If ((Get-Datastore $SSD_DSName) -eq $True){
	Write-Host "Datastore, $SSD_DSName Already Exists Please make sure the target host has been reverted or that you're not using an already taken 3-letter Branch Code."
	return
	}
else
	{
	Get-Datastore -Name datastore1 | Set-Datastore -Name $SSD_DSName
	}

#Build Second Datastore
$DS_Suffix = "-HDD"
$HDD_DSName = $DatacenterLocation + $DS_Suffix
$SCSIID = Get-VMHost $VMHost | Get-ScsiLun | where CapacityGB -GT 1000
$SCSIID = $SCSIID.CanonicalName
New-Datastore -VMHost $VMHost -Name $HDD_DSName -Path $SCSIID

#Certify DS Creation
Write-Host "Verifying Datastore Creations..." -ForegroundColor Cyan -BackgroundColor Black
    Start-Sleep -Seconds 2
Get-Datastore | select Name,CapacityGB,FreeSpaceGB,Type | Format-Table -AutoSize
	Start-Sleep -Seconds 2

# Moving Files from USB to New Datastores
	$Folder_Suffix = "-Templates"
	$FolderString = $DatacenterLocation + $Suffix
	$PSDrive_LocationSSD = Get-Datastore $SSD_DSName

Write-Host "Transferring ISOs and OVAs..." -ForegroundColor Cyan -BackgroundColor Black
	Start-Sleep -Seconds 2
	New-PSDrive -Location $PSDrive_LocationSSD -Name Target -PSProvider VimDatastore -Root "\"
Set-Location -Path USB:\
	mkdir -Path Target:\ -Name ISOs
		Copy-DatastoreItem -Item USB:\ISOs\* -Destination Target:\ISOs\
	mkdir -Path Target:\ -Name OVAs
		Copy-DatastoreItem -Item USB:\OVAs\* -Destination Target:\OVAs\
	mkdir -Path Target:\ -Name BranchTemplate
		Copy-DatastoreItem -Item USB:\BranchTemplate\* -Destination Target:\BranchTemplate\	

# Disconnecting USB Drive
Write-Host "Disconnecting USB Drive..." -ForegroundColor Cyan -BackgroundColor Black
	Start-Sleep -Seconds 2
	Get-Datastore $datastoreUSB | Unmount-Datastore

### Networking Operations ###
Write-Host "Beginning Network Switch and PG Changes" -ForegroundColor Cyan -BackgroundColor Black
    Start-Sleep -Seconds 2

If ((Get-VirtualPortGroup -Name NOC,FT_VMOTION,VSPHERE_REPLICATION,Staging-DHCP) -eq $True) {
Write-Host "Port Groups Exist Already, Please Ensure that you have a clean/rolled-back host.  Stopping Script - Please address configurations"
return
}
else 
{
Write-Host "Setting up Port Groups on vSwitch0" -ForegroundColor Cyan -BackgroundColor Black
Start-Sleep -Seconds 4
}

#Portgroup Addtions - vSwitch0
	New-VirtualPortGroup -Name "NOC" -VirtualSwitch vSwitch0
	New-VirtualPortGroup -Name "FT_VMOTION" -VirtualSwitch vSwitch0
	New-VirtualPortGroup -Name "VSPHERE_REPLICATION" -VirtualSwitch vSwitch0
	New-VirtualPortGroup -Name "Staging-DHCP" -VirtualSwitch vSwitch0

#Create New Switch for second vNIC on VMHOST
Write-Host "Creating vSwitch1" -ForegroundColor Cyan -BackgroundColor Black
Start-Sleep -Seconds 2
	New-VirtualSwitch -Name vSwitch1 -Nic vmnic1

#Portgroup Additions - vSwitch1
Write-Host "Setting up PG's on vSwitch1" -ForegroundColor Cyan -BackgroundColor Black
    Start-Sleep -Seconds 2 
New-VirtualPortGroup -Name "VLAN1" -VLanId 1 -VirtualSwitch vSwitch1
New-VirtualPortGroup -Name "VLAN50" -VLanId 50 -VirtualSwitch vSwitch1
New-VirtualPortGroup -Name "VLAN120" -VLanId 120 -VirtualSwitch vSwitch1
New-VirtualPortGroup -Name "VLAN128" -VLanId 128 -VirtualSwitch vSwitch1

#Remove Default PortGroup(s)
Write-Host "Removing Old Port Groups" -ForegroundColor Cyan -BackgroundColor Black
    Start-Sleep -Seconds 2
Get-VirtualPortGroup -Name "VM Network" | Remove-VirtualPortGroup -Confirm:$false

#Add Server to Branch vCenter
Write-Host "Connecting to Branch vCenter (ROBO)" -ForegroundColor Cyan -BackgroundColor Black
    Start-Sleep -Seconds 4
	$BranchVC = "branchvc01.ad.he-equipment.com"
Connect-VIServer -Server $BranchVC -Credential $CredentialBranchVC
Write-Host "Adding Host to Branch vCenter" -ForegroundColor Cyan -BackgroundColor Black
	Start-Sleep -Seconds 3
	Add-VMHost $VMHost -Location NOCBranch -User root -Password vmware123 -Force -Confirm:$false
	#Kill ESXi Direct Connect - We're switching to vCenter Ops from here on down
	Disconnect-VIServer $VMHost -Confirm:$false

#Restablish Variable(s) for Streamline
$SSD = Get-Datastore $SSD_DSName
$HDD = Get-Datastore $HDD_DSName

Set-Location -Path C:\

Remove-PSDrive -Name Target
New-PSDrive -Location $SSD -Name Target -PSProvider VimDatastore -Root "\"

#Add Template to Inventory
Write-Host "Clone Template - Operations" -ForegroundColor Cyan -BackgroundColor Black
    Start-Sleep -Seconds 2
	$VMXFile = "[$SSD] BranchTemplate/BranchWin2012R2TMPL.vmx"
	$TemplateSuffix = "Win12TMPL"
	$NewTemplateName = $DatacenterLocation + $TemplateSuffix
#Checking for Template files.  This is a major issue sometimes
If ((Test-Path Target:\BranchTemplate\BranchWin2012R2TMPL.vmx) -eq $false){
Write-Host ""
Write-Host "BranchWin2012R2 Template is NOT located in $SSD or there has been a critical error." -ForegroundColor White -BackgroundColor Red
Write-Host "Please Verify that the USB Tranferred Files over to the SSD - Rollback server and start again" -ForegroundColor White -BackgroundColor Red
Write-Host ""
}
else 
{
	Write-Host "Template found on $SSD, Deploying Template"
	New-VM -Name $NewTemplateName -VMHost $VMHost -VMFilePath $VMXFile
	Move-VM -VM $NewTemplateName -Datastore $SSD
	Get-VM -Name $NewTemplateName | Set-VM -ToTemplate -Confirm:$false
}

#Deploy Windows 2012 R2 Template
# OU Path: OU=BRANCH_SERVERS,OU=SERVERS,OU=HE,DC=ad,DC=he-equipment,DC=com
$SuffixNAS = "NAS01"
$NewNASName = $DatacenterLocation + $SuffixNAS
Write-Host "Deploying $NewTemplateName as $NewNASName" -ForegroundColor Cyan -BackgroundColor Black
	Start-Sleep -Seconds 2
	New-ADComputer -Credential $CredentialBranchVC -Name $NewNASName -SamAccountName $NewNASName -Path "OU=BRANCH_SERVERS,OU=SERVERS,OU=HE,DC=ad,DC=he-equipment,DC=com" -Enabled $true -Location $DatacenterLocation
	New-VM -Name $NewNASName -VMHost $VMHost -Template $NewTemplateName -Datastore $HDD -OSCustomizationSpec DomainJoinBranch -DiskStorageFormat Thin
	Get-VM -Name $NewNASName | Get-NetworkAdapter | Set-NetworkAdapter -NetworkName Staging-DHCP -Confirm:$false -ErrorAction SilentlyContinue 
	Start-VM -VM $NewNASName

#ISO Movement for Storage
Write-Host "Deploying the VX-1000 (PAN)" -ForegroundColor Cyan -BackgroundColor Black
	Start-Sleep -Seconds 2

#Deploy VX-1000 OVA
$SuffixVX = "-VX-1000"
$VXString = $DatacenterLocation + $SuffixVX
Import-VApp -Source "\\hefs\IT\SilverPeak\VX-1000-7.3.2.0_57392.ova" -VMhost $VMHost -Datastore $SSD -Name $VXString -Force -DiskStorageFormat Thin
	#Adding the Adapters and defaulting to VLAN1	
	Get-VM $VXString | Get-NetworkAdapter | Set-NetworkAdapter -NetworkName VLAN1 -Confirm:$false -ErrorAction SilentlyContinue
	Get-VM $VXString | New-NetworkAdapter -NetworkName VLAN1 -StartConnected -Type VMXNET3 -Confirm:$false

#Verification Checks for Visual - this will be seen only if script is being ran in Powershell/ISE
Write-Host "Verifying Host" -ForegroundColor Cyan -BackgroundColor Black
	Start-Sleep -Seconds 2
Get-VMHost $VMHost -Location NOCBranch | select Name,Build,ConnectionState
	Start-Sleep -Seconds 2
Write-Host "Verifying Switch Design and Build" -ForegroundColor Cyan -BackgroundColor Black
	Start-Sleep -Seconds 2
Get-VMHost $VMHost | Get-VirtualPortGroup | select Name,VLanId,VirtualSwitch | Format-Table -AutoSize -GroupBy VirtualSwitch
	Start-Sleep -Seconds 2

#VMware Automation Script End - Disconnecting Host and vCenter
Write-Host "Script Complete: Disconnecting vCenter and ESXi Host from Strings" -ForegroundColor Cyan -BackgroundColor Black
	Start-Sleep -Seconds 2
	Disconnect-VIServer * -Confirm:$false

Write-Host "VI Servers are now Disconnected, Script is complete - Please allow 5-10 Minutes for the VM to complete Guest OS Customization" -ForegroundColor Cyan -BackgroundColor Black

############################
# Begin NAS Customization  #
############################

$FQDNSuffix = ".ad.he-equipment.com"
$NewNASFQDN = $NewNASName + $FQDNSuffix
Write-Host ""
Write-Host "#############################" -ForegroundColor Cyan -BackgroundColor Black
Write-Host "Starting NAS Customization..." -ForegroundColor Cyan -BackgroundColor Black
Write-Host "#############################" -ForegroundColor Cyan -BackgroundColor Black
Write-Host ""
	Start-Sleep -Seconds 5

#Loop for WinRM Status, we want the script to hold until WinRM Comes online for the remote server
    while ( (Get-Service -Name WinRM -ComputerName $NewNASFQDN).Status -ne "Running" ) {
        "VMware Guest OS Customization Occurring, Waiting for $NewNASFQDN To Come Online..."
        Start-Sleep -Seconds 120
		ipconfig /flushdns | Out-Null
    }
    "$NewNASFQDN is Up! Starting Process"
		Start-Sleep -Seconds 60

Write-Host "Entering Powershell Remote Session on $NewNASFQDN" -ForegroundColor Cyan -BackgroundColor Black
#Start Working on NAS
$NasSession = New-PSSession -ComputerName $NewNASFQDN -Credential $CredentialBranchVC
Start-Sleep -Seconds 15

Invoke-Command -Session $NasSession -ScriptBlock {
Import-Module ServerManager
#Start Basic Service Installations
	Install-WindowsFeature Net-Framework-Core
	Install-WindowsFeature -Name 'DHCP' -IncludeManagementTools
	Install-WindowsFeature -Name FS-DFS-Replication -IncludeManagementTools
	Install-WindowsFeature -name AD-Domain-Services -IncludeManagementTools

#Check if SNMP-Service is already installed
$check = Get-WindowsFeature -Name SNMP-Service
	If ($check.Installed -ne "True") {
	#Install/Enable SNMP-Service
	Write-Host "SNMP Service Installing..."
	Get-WindowsFeature -name SNMP* | Add-WindowsFeature -IncludeManagementTools
	}

#Display Windows Features installed
Write-Host "Windows Features Completed, displaying Installed Features"
	Start-Sleep -Seconds 30
	Get-WindowsFeature | Where Installed | select Name,DisplayName,PSComputerName,Installed,InstallState | Format-Table -AutoSize

Write-Host "Completed NAS Customization for $NewNASName" -ForegroundColor Cyan -BackgroundColor Black
}

Write-Host "Exiting PS Session" -ForegroundColor Cyan -BackgroundColor Black
	Remove-PSSession -Session $NasSession
	Start-Sleep -Seconds 3

Stop-Transcript

cd C:\

# END #