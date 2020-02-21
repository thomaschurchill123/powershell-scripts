<#
.SYNOPSIS
	Compare PVS vDisk Stores
.DESCRIPTION
	Script will check for differences between the PVS vDisk stores. The PVS stores in use currently are hardcoded into the script, any future stores will need to be manually added.
.EXAMPLE
	Firstly run "Import-Module Compare-PVSStores"
    Then run "Compare-PVSStores"  from the PS window.
.NOTES
    Tom Churchill, v1.1, 18/06/2019 - Updated Output
    Tom Churchill, v1.0, 06/06/2019
#>
function Compare-PVSStores {
    $pvs001 = Get-ChildItem -path '\\PVS_SERVER_01\d$\vDisks'
    $pvs002 = Get-ChildItem -path '\\PVS_SERVER_02\d$\vDisks'
    $compare = Compare-Object -ReferenceObject $pvs001 -DifferenceObject $pvs002
    $compare | Where-Object {$_.InputObject -like "*.avhdx*" -or $_.InputObject -like "*.vhdx*" -or $_.InputObject -like "*.pvp*"} # Extract vdisk files
}
