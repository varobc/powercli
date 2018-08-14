######################################################################
# NAME: PatchHost.ps1
# AUTHOR: Rob Cox
# DATE: 08/13/19
# 
# PowerCLI Script to Patch Non-Clustered Hosts
#
# VERSION HISTORY
# 1.0	08/13/19	Initial Version 
######################################################################

# Connect to vCenter
connect-viserver 

# List hosts to select
write-host ""
write-host "Select vSphere Host to Shutdown VMs and Patch:"
write-host ""
$IHOST = Get-VMhost | Select Name | Sort-object Name
$i = 1
$IHOST | %{Write-Host $i":" $_.Name; $i++}
$DSHOST = Read-host "Enter the Number of the Host You Wish to Patch."
$SHOST = $IHOST[$DSHOST -1].Name
write-host "You Have Selected $($SHOST)."

# Creates variable for all Powered On VMs on host
$vms = Get-vmhost -name $SHOST | Get-VM | Where-object {$_.PowerState -eq "PoweredOn"}

# Guest Shutdown for all VMs with VMware Tools running 
write-host "Powering Down VMs with VMware Tools Running"
$vms | where-object {$_.ExtensionData.Guest.ToolsStatus -eq "toolsOk"} | Shutdown-VMGuest -Confirm:$false 
$vms | where-object {$_.ExtensionData.Guest.ToolsStatus -eq "toolsOld"} | Shutdown-VMGuest -Confirm:$false 

# Powers Off all VMs where VMware Tools have not been installed or are not running
write-host "Powering Down VMs without VMware Tools Running"
$vms | where-object {$_.ExtensionData.Guest.ToolsStatus -eq "toolsNotInstalled"} | Stop-VM -Confirm:$false
$vms | where-object {$_.ExtensionData.Guest.ToolsStatus -eq "toolsNotRunning"} | Stop-VM -Confirm:$false

# Wait 60 seconds before Powering Off hung VMs 
write-host "Waiting 60 Seconds before Hard Powering Off Any Hung VMs"
write-host "Press Ctrl+C to Cancel"
Start-sleep -s 60
$vms | Stop-VM -Confirm:$false
write-host "All VMs Powered Off"

# Scan selected host
write-host "Scanning Host"
test-compliance -entity $SHOST
 
# Display compliance results and wait 30 seconds
get-compliance -entity $SHOST
start-sleep -s 30
 
# Place selected host into Maintenance mode
write-host "Placing $($SHOST) in Maintenance Mode"
Get-VMHost -Name $SHOST | set-vmhost -State Maintenance
 
# Remediate selected host for Host Patches
write-host "Deploying VMware Host Critical & Non-Critical Patches"
get-baseline -name *critical* | remediate-inventory -entity $SHOST -confirm:$false
 
# Remove selected host from Maintenance mode
write-host "Removing $($SHOST) from Maintenance Mode"
Get-VMHost -Name $SHOST | set-vmhost -State Connected

# Power on VMs shutdown after maintenance
write-host "Starting Virtual Machines"
$vms | Start-VM -Confirm:$false
start-sleep -s 10

# Complete
write-host "The Patching for $($SHOST) is Now Complete"

