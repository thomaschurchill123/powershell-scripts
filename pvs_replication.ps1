<#
	 .SYNOPSIS
			 Replicate two PVS Stores.

	 .DESCRIPTION
      This script will mirror the vDisk store of the primary PVS server to the vDisk store of the secondary server.
      Any vDisks that have been set to not use load balancing will be excluded as replication is not necessary.
      Any vDisk versions that are set to maintenance will be exluded too, as generally changes are in progress on these versions,
      complete the required changes and mark the version as either production or test before replicating.

   .FUNCTION
      Log
      Write a message to a log file to detail script actions for later review.


	 .LINK
			 Robocopy command string taken from https://carlstalhood.com/provisioning-serivces-server-install/#robocopy

	 .NOTES
	 		 Version:        1.0
			 Author:         Thomas Churchill
			 Creation Date:  05/06/2019
			 Purpose/Change: Initial script development

       Version:        2.0
			 Author:         Thomas Churchill
			 Creation Date:  18/02/2020
			 Purpose/Change: Updated script to more intelligently target vDisks and
       include .pvp files in exclusion list.

#>

# Modules
asnp Citrix*

# Functions
Function Log {
    param(
        [Parameter(Mandatory=$true)][String]$msg
    )
    $log_date = Get-Date -Format yyyy_MM_dd_HH_mm
    $log_file = "$log_date"+"_Replication_Log.txt"
    Add-Content $log_file $msg
}

# Variables
$pvs001 = "PVS_Server_01"
$pvs002 = "PVS_Server_02"
$vdisk_store = "STORENAME"
$site = "SITENAME"
$pvs001_vdisks = "\\$pvs001\D$\vDisks\"
$pvs002_vdisks = "\\$pvs002\D$\vDisks\"
$lb_disks = Get-PVSDiskInfo | where {$_.ServerName -eq ""} # Get list of vDisks which are load balance enabled. 
$non_lb_disks = Get-PVSDiskInfo | where {$_.ServerName -ne ""} # Get list of vDisks which are not load balance enabled.
$file_exclusion_list = @(
"*.lok"
) # list of files to exclude from copy.
$log_date = Get-Date -Format yyyy_MM_dd_HH_mm
$log_file = "$log_date"+"_Replication_Log.txt"

# Main Script
# Add non load balanced disks to exclusion list.
Log "Checking for files to exclude..."
foreach($disk in $non_lb_disks){
    $disk_version = Get-PvsDiskVersion -DiskLocatorName $disk.Name -SiteName $site -StoreName $vdisk_store
    foreach($v in $disk_version){
        $file_exclusion_list += $v.DiskFileName.Substring(0, $v.DiskFileName.LastIndexOf('.'))+".pvp"
        Log "$($v.DiskFileName.Substring(0, $v.DiskFileName.LastIndexOf('.'))+".pvp") added to file exclusion list, load balancing is disabled."
        $file_exclusion_list += $v.DiskFileName
        Log "$($v.DiskFileName) added to file exclusion list, load balancing is disabled."
    } # End foreach loop
} # End foreach loop

# Add disk maintenance versions to exclusion list.
foreach($disk in $lb_disks){
    $disk_version = Get-PvsDiskVersion -DiskLocatorName $disk.Name -SiteName $site -StoreName $vdisk_store
    foreach($v in $disk_version){
        if($v.Access -eq "1" -or $v.Access -eq "2"){
            $file_exclusion_list += $v.DiskFileName
            Log "$($v.DiskFileName) added to file exclusion list, disk version is maintenance."
            $file_exclusion_list += $v.DiskFileName.Substring(0, $v.DiskFileName.LastIndexOf('.'))+".pvp"
            Log "$($v.DiskFileName.Substring(0, $v.DiskFileName.LastIndexOf('.'))+".pvp") added to file exclusion list, disk version is maintenance."
        } # End if
    } # End foreach loop
} # End foreach loop

Log "Exclusion checks complete."
Log "The following files will be excluded:"
Log "$file_exclusion_list"
Log "Starting Robocopy..."

# Robocopy command to replicate stores.
Robocopy.exe $pvs001_vdisks $pvs002_vdisks *.vhd *.vhdx *.avhd *.avhdx *.pvp /b /mir /xf $file_exclusion_list /xd WriteCache DfsrPrivate /xo /xn /log+:C:\Scripts\PVS_Replication\$log_file /tee
