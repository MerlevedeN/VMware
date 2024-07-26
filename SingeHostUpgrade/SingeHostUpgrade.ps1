#
#   Version:        1.0
#   Author:         MerlevedeN - https://github.com/MerlevedeN
#
#   Creation Date:  2024/07/26
#   Purpose/Change: This script creates a custom ESXi upgrade image with the net-community-driver. Uploads it to the single host and upgrade the host.
#
#   Change: <DATE> : <CHANGE> (Also change Version)
#   Change: 2024/07/26 : Creation

# Variables
$SingleHost = "<Host IP>"
$UpgradeBundle = "VMware-ESXi-8.0U3-24022510-depot.zip"
$NetBundle = "Net-Community-Driver_1.2.7.0-1vmw.700.1.0.15843807_19480755.zip"
$build = "ESXi-8.0U3-24022510"

# Get Credentials
$Credentials = Get-Credential -Message "Please enter your credentials to log on to vCenter"

# Connect to Singe Host
Write-Host "Connecting to $($SingleHost)..." -ForegroundColor Yellow
Connect-VIServer -Server $SingleHost -Credential $Credentials | Out-Null

# Get host information
$Version = Get-VMHost $SingleHost | Select-Object Version, Build, Name
Write-host "Host information before upgrade: " -ForegroundColor Green
Write-Host "Version: " -ForegroundColor Blue -NoNewline
Write-host $Version.Version
Write-Host "Build: " -ForegroundColor Blue -NoNewline
Write-host $Version.Build

# Set timeout settings for web tasks
# https://vdc-download.vmware.com/vmwb-repository/dcr-public/ef3281e2-e1d8-4ee3-8c81-52ff40b3562c/bdd425a6-94f0-491b-b3cc-6d3345757fc8/GUID-4F61FB46-5917-4979-88BB-DF5649167CF3.html
$initialTimeout = (Get-PowerCLIConfiguration -Scope Session).WebOperationTimeoutSeconds
Set-PowerCLIConfiguration -Scope Session -WebOperationTimeoutSeconds 1800 -Confirm:$false | Out-Null

# Check running VM's
Write-Host "Check if there are running VMs" -ForegroundColor Yellow
$RunningVMs = get-vm | Where-Object PowerState -like "PoweredOn"

if ($RunningVMs.count -ne 0){
    Write-Host "There are $($RunningVMs.count) running VMs! " -ForegroundColor Red
    $PowerOff = Read-Host -Prompt 'Power Off the Running VMs? (Y/N)'

    if ($PowerOff.ToUpper() -eq "Y") {
        $RunningVMs | Stop-VM -Confirm:$false | Out-Null
        Write-Host "Waiting for VMs to power off..." -ForegroundColor Yellow
        while ((get-vm | Where-Object PowerState -like "PoweredOn").count -ne 0){
            Write-Host "Waiting for VMs to power off..." -ForegroundColor Yellow
            Start-Sleep -Seconds 15
        }
        Write-Host "All VMs are powered off." -ForegroundColor Green
    }else {
        exit
    }
} 

# Place the host in maintenance mode
Write-Host "Placing $SingleHost in maintenance mode..." -ForegroundColor Yellow
Get-VMHost $SingleHost | Set-VMHost -State Maintenance | Out-Null
while ((Get-VMHost $SingleHost).connectionState -ne "Maintenance"){
    Write-Host "Waiting for host to go in Maintenance..." -ForegroundColor Yellow
    Start-Sleep 10
}

# Creating bundle with community networkdrivers for Intel NUC

Add-EsxSoftwareDepot $UpgradeBundle
Add-EsxSoftwareDepot $NetBundle
New-EsxImageProfile -CloneProfile "$($build)-standard" -name "$($build)-standard-NUC" -Vendor "MerlevedeN"
Add-EsxSoftwarePackage -ImageProfile "$($build)-standard-NUC" -SoftwarePackage "net-community"
Export-ESXImageProfile -ImageProfile "$($build)-standard-NUC" -ExportToBundle -filepath "$($build)-standard-NUC.zip" -Force

# Copy bundle to datastore
Write-Host "Uploading bundle to datastore..." -ForegroundColor Yellow
$datastore = Get-Datastore
Copy-DatastoreItem -Item "$($build)-standard-NUC.zip" -Destination $datastore.DatastoreBrowserPath

# Run esxcli with powercli
Write-Host "Creating update bundle..." -ForegroundColor Yellow
$esxcli = get-esxcli -VMHost $singlehost -v2
$InstArgs = $esxcli.software.profile.install.createargs()
$InstArgs.depot = $datastore.ExtensionData.Info.url  + "/"+ "$($build)-standard-NUC.zip"
$InstArgs.profile = "$($build)-standard-NUC"

Write-Host "Installing update bundle..." -ForegroundColor Yellow
$esxcli.software.profile.install.Invoke($InstArgs)

# Set timeout settings to original
Set-PowerCLIConfiguration -Scope Session -WebOperationTimeoutSeconds $initialTimeout  -Confirm:$false | Out-Null

Write-Host "Rebooting $($SingleHost)!" -ForegroundColor Red
Get-VMHost $SingleHost | Restart-VMHost -Confirm:$false

Write-Host "Sleeping... (5 min)" -ForegroundColor Cyan
Start-Sleep -Seconds 300

# Connect to Singe Host
Write-Host "Connecting to $($SingleHost)..." -ForegroundColor Yellow
Connect-VIServer -Server $SingleHost -Credential $Credentials | Out-Null

# Get host information
$Version = Get-VMHost $SingleHost | Select-Object Version, Build, Name
Write-host "Host information after upgrade: " -ForegroundColor Green
Write-Host "Version: " -ForegroundColor Blue -NoNewline
Write-host $Version.Version
Write-Host "Build: " -ForegroundColor Blue -NoNewline
Write-host $Version.Build

# Exit maintenance mode
Get-VMHost $SingleHost | Set-VMHost -State Connected | Out-Null

# Poweron the VM's
Write-Host "Starting VMs" -ForegroundColor Green
$RunningVMs | Start-VM -Confirm:$false | Out-Null

Write-Host "Disconnecting from $($SingleHost)..." -ForegroundColor Yellow
disconnect-VIServer -Server $SingleHost -Confirm:$false  | Out-Null
