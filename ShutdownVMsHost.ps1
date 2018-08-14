######################################################################
# NAME: ShutdownVMsHost.ps1
# AUTHOR: Rob Cox
# DATE: 08/13/19
# 
# PowerCLI Script to Gracefully Shutdown VMs on a Host
#
# VERSION HISTORY
# 1.0	08/13/19	Initial Version 
######################################################################

# Connect to vCenter
connect-viserver 

# List hosts to select
write-host ""
write-host "Select vSphere Host to Shutdown VMs:"
write-host ""
$IHOST = Get-VMhost | Select Name | Sort-object Name
$i = 1
$IHOST | %{Write-Host $i":" $_.Name; $i++}
$DSHOST = Read-host "Enter the number of the host you wish to have all VMs Shutdown."
$SHOST = $IHOST[$DSHOST -1].Name
write-host "You have selected $($SHOST)."

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
