##
# PVS Patching Prep
# WIP, ver 0.1 18/02/20, Thomas Churchill
##

# Functions
Function Log {
    param(
        [Parameter(Mandatory=$true)][String]$msg
    )
    $log_date = Get-Date -Format yyyy_MM_dd
    $log_file = "$log_date"+"_PatchingLog.txt"
    Add-Content C:\scripts\PVS_Patching\$log_file $msg
}

# Modules
asnp Citrix.*

# Variables
$current_month = Get-Date -Format MMMMM
$vdisks = Get-PvsDiskInfo | select Name
$storename = "STORE_NAME"
$sitename = "SITE_NAME"
$date = Get-Date
$date_log = $date | Get-Date -Format "dd_MM_yy HH:mm"
$last_month = $date.AddDays(-30)|Get-Date -Format MMMMM


# Main Script
Log "Script started @ $date_log"
do{
    clear
    Write-Host ""
    Write-Host "******************************"
    Write-Host "** PVS Patching Preparation **"
    Write-Host "******************************"
    Write-Host ""
    Write-Host "Select Disks to Prepare.."
    Write-Host ""

    $menu = @{}
    for($i = 1; $i -le $vdisks.Count; $i++)
    {
        Write-Host "$i - $($vdisks[$i-1].Name)"
        $menu.Add($i,($vdisks[$i-1].Name))
    } # End for loop

    Write-Host ""
    Write-Host "0 - Quit"
    Write-Host ""
    [int]$ans = Read-Host "Select number(s)"
    if($ans -gt 0){
    $selection_validation = $menu.($ans) #'^([1-9]|[1][0-9]|[2][0-5])$'
        if (-not $selection_validation){
            Write-Host -ForegroundColor Red "Invalid selection.."
            Start-Sleep -Seconds 2
            Write-Host ""
        } # End if
        else {
            Log "Selected $($menu.($ans)) for preparation, validating..."
            $vdisk_versions = Get-PvsDiskVersion -DiskLocatorName $menu.($ans) -StoreName $storename -SiteName $sitename
            if($vdisk_versions.Count -gt 1){
                Log "$($menu.($ans)) vDisk version count higher than 1, please check to see if vDisks require merging or make another selection."
                Write-Host -ForegroundColor Red "vDisk version count higher than 1, please check to see if vDisks require merging or make another selection."
                Start-Sleep -Seconds 2
            }
            else{
                Log "vDisk $($menu.($ans)) appears to have been merged, creating new vDisk..."
                Write-Host "vDisk $($menu.($ans)) appears to have been merged, creating new vDisk..."
                if($menu.($ans) -like "*$last_month"){
                   $old_name = $menu.($ans)
                   $new_name = $old_name.Replace($last_month,$current_month)+".vhdx"
                   if(Test-Path "\\PVS_Server_01\D$\vDisks\$new_name"){
                        Log "File $new_name already exists, check vDisk store on PVS001"
                        Write-Host "File $new_name already exists, check vDisk store on PVS001"
                   }
                   else{
                        Write-Host "creating $new_name..."
                        Log "creating $new_name"
                        Copy-Item -Path "\\PVS_Server_01\D$\vDisks\$($vdisk_versions.DiskFileName)" -Destination "\\PVS_Server_01\D$\vDisks\$new_name"
                        Write-Host "importing $new_name into PVS"
                        New-PvsDiskLocator -Name $new_name.Split('.')[0] -StoreName $storename -SiteName $sitename -VHDX
                        Set-PvsDisk -Name $new_name.Split('.')[0] -SiteName $sitename -StoreName $storename -WriteCacheType "9" -WriteCacheSize "8192"
                        New-PvsDiskMaintenanceVersion -DiskLocatorName $new_name.Split('.')[0] -SiteName $sitename -StoreName $storename
                   }
                } # End if

            }
        } # End else
    }
} until ($ans -eq 0)

Log "Script finished @ $date_log"
