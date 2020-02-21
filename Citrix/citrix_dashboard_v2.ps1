<#
.SYNOPSIS
    Citrix platform Dashboard.
.Description
    Gathers data and produces a HTML report/dashboard overview of the Citrix platform.
    Script should be run as a scheduled task. HTML file will be sent to C:\inetpub\wwwroot\Dashboard
    and can be accessed by connecting to https://*director_server*.domain.net\Dashboard.
    Primarily uses the PS module Dashimo to produce the report.
.Notes
    Author - Thomas Churchill - Date - 08/07/19 - Version 1.0
           - Thomas Churchill - Date - 08/11/19 - Version 2.0
                            - Added simplified service desk dashboard, easier to read due to setup of monitoring dashboards. Designed for big screens at end of office.
#>

# Modules for import
asnp Citrix.* # Citrix modules
Import-Module dashimo # Dashimo module and all its dependencies
Import-Module C:\Scripts\Dashboard\Functions\dash_functions.ps1 # Custom functions for dashboard

# Variables
$date = Get-Date -Format "dd/MM/yyyy HH:mm:ss" # Current date and time
$admin_html_path = "C:\inetpub\wwwroot\Dashboard\admindashboard.html" # Location for HTML file (Admin Dash)
$sd_html_path = "C:\inetpub\wwwroot\Dashboard\sddashboard.html" # Location for HTML file (SD Dash)
$customer_matrix = Import-Csv C:\Scripts\CustomerMatrix\customermatrix.csv
$core_servers = Import-Csv C:\Scripts\CoreServerList\CoreServerList.csv
$session_data = Get-BrokerSession -AdminAddress "delivery_controller.fqdn" -MaxRecordCount 3000 # Gather Citrix Session information
$machine_data = Get-BrokerMachine # Gather Citrix server information
$license_data = Get-WmiObject -Class "Citrix_GT_License_Pool" -Namespace "ROOT\CitrixLicensing" -ComputerName "license_server.fqdn" # Gather information on Citrix Licensing
$services_table = @{
Delivery_Controller = "CitrixBrokerService","CitrixADIdentityService","CitrixConfigurationService"
StoreFront = "W3SVC"
PVS = "DHCPServer","BNTFTP"
License = "Citrix Licensing","Citrix_GTLicensingProv","CitrixWebServicesforLicensing"
Director = "IISAdmin","W3SVC"
} # List of services per server role to check
$session_table = foreach($customer in $customer_matrix){
    $customer_deliverygroup = $customer.DeliveryGroupId
    $average_load_arr = @()
    $average_users_arr = @()
    $average_load_loop = foreach($m in $machine_data | where {$_.DesktopGroupUid -eq $customer_deliverygroup -and $_.InMaintenanceMode -like "False"}){
        $average_load_arr += $m.LoadIndex
    }
    $average_load = $average_load_arr | Measure-Object -Average | select Average -ExpandProperty Average
    $average_users_loop = foreach($m in $machine_data | where {$_.DesktopGroupUid -eq $customer_deliverygroup -and $_.InMaintenanceMode -like "False"}){
        $average_users_arr += $m.SessionCount
    }
    $average_users = $average_users_arr | Measure-Object -Average | select Average -ExpandProperty Average
    [pscustomobject]@{
    Customer = $customer.customer
    Connected = ($session_data | where {$_.DesktopGroupUid -eq "$customer_deliverygroup" -and $_.SessionState -like "*Active*"}).count
    "Disconn." = ($session_data | where {$_.DesktopGroupUid -eq "$customer_deliverygroup" -and $_.SessionState -like "*Disconnected*"}).count
    Total = ((($session_data | where {$_.DesktopGroupUid -eq "$customer_deliverygroup" -and $_.SessionState -like "*Active*"}).count) + (($session_data | where {$_.DesktopGroupUid -eq "$customer_deliverygroup" -and $_.SessionState -like "*Disconnected*"}).count))
    Idle = ($session_data | where {$_.DesktopGroupUid -eq "$customer_deliverygroup" -and $_.IdleDuration -gt "00:00:00"}).count
    Servers = ($machine_data | where {$_.DesktopGroupUid -eq "$customer_deliverygroup"}).count
    "Avg Load (%)" = [math]::Round(($average_load)/10000*100,2)
    "Avg Sessions" = [math]::Round($average_users,2)
    }
} # Sort session data for use in HTML report
$machine_table = foreach($m in $machine_data){
    $loadindex_percent = (($m.LoadIndex)/10000) * 100 # Work out Load Evaluator Index as a percentage
    [pscustomobject]@{
    Server = $m.MachineName.Split("\")[1]
    "Delivery Group" = $m.DesktopGroupName
    "Load Index (%)" = $loadindex_percent
    Sessions = $m.SessionCount
    "Reg State" = $m.RegistrationState
    "Maintenance" = $m.InMaintenanceMode
    }
} # Sort machine data for use in HTML report
$infra_table = foreach($s in $core_servers){
    $services = Test-Services -services $services_table.($s.role) -computername $s.FQDN
    $cpu = Check-CPU -hostname $s.Hostname
    $mem = Check-Memory -hostname $s.Hostname
    if($s.role -eq "Delivery_Controller"){
    $sql_test = Get-BrokerDBConnection -AdminAddress $dc_fqdn
        if($sql_test){
        $sql_status = $sql_test.Split(";")[0]
        }
        else{
        $sql_status = "ERRROR"
        }
    }
    else{
    $sql_status = "n/a"
    }
    [pscustomobject]@{
    Name = $s.Hostname
    Role = $s.Role
    Services = $services
    "SQL Status" = $sql_status
    "CPU (%)" = $cpu
    "Memory (%)" = $mem
    }
} # Test CPU, Memory and Services of core Citrix servers
$licensing_table = foreach($l in $license_data){
    [pscustomobject]@{
    Name = $l.PLD
    Count = $l.Count
    Used = $l.InUseCount
    Remaining = (($l.count)-($l.InUseCount))
    Overdraft = $l.Overdraft
    }
} # Sort licensing data for use in HTML report

# Build Admin HTML report
Dashboard -Name 'Citrix Admin Dashboard' -FilePath $admin_html_path -AutoRefresh 300 {
    Tab -Name 'Overview' -Heading "$date" {
        Section -Name 'Citrix Sessions' -Invisible {
            Section -Name 'Citrix Sessions' -Collapsable {
                Table -DataTable $session_table -DisableSearch -DisablePaging -Buttons copyHtml5,csvHtml5,pdfHtml5,excelHtml5 -HideFooter -DefaultSortColumn "Avg Load (%)" -DefaultSortOrder Descending{
                    TableConditionalFormatting -Name 'Avg Load (%)' -ComparisonType number -Operator gt -Value 70 -BackgroundColor Yellow -Row
                    TableConditionalFormatting -Name 'Avg Load (%)' -ComparisonType number -Operator gt -Value 90 -BackgroundColor Red -Row
                }
            }
            Section -Name 'Servers by Load' -Collapsable {
                Table -HideFooter -DataTable $machine_table -DefaultSortColumn "Load Index (%)" -DefaultSortOrder Descending {
                    TableConditionalFormatting -Name 'Load Index (%)' -ComparisonType number -Operator gt -value 70 -BackgroundColor Yellow -Row
                    TableConditionalFormatting -Name 'Load Index (%)' -ComparisonType number -Operator gt -Value 90 -BackgroundColor Red -Row
                    TableConditionalFormatting -Name 'Load Index (%)' -ComparisonType number -Operator eq -Value 100 -BackgroundColor Red -Row
                    TableConditionalFormatting -Name 'Reg State' -ComparisonType string -Operator eq -Value "Unregistered" -BackgroundColor Red
                }
            }
        }
        Section -Name 'Citrix Infrastructure' -Invisible {
            Section -Name 'License Status' -Collapsable {
                Table -DataTable $licensing_table -HideFooter -DisablePaging -DisableSearch -Buttons copyHtml5,csvHtml5,pdfHtml5,excelHtml5
            }
            Section -Name 'Citrix Infrastructure' -Collapsable {
                Table -DataTable $infra_table -HideFooter -Buttons copyHtml5,csvHtml5,pdfHtml5,excelHtml5 -DisablePaging -DisableSearch {
                    TableConditionalFormatting -Name 'CPU (%)' -ComparisonType number -Operator gt -Value 70 -BackgroundColor Yellow
                    TableConditionalFormatting -Name 'CPU (%)' -ComparisonType number -Operator gt -Value 90 -BackgroundColor Red
                    TableConditionalFormatting -Name 'CPU (%)' -ComparisonType number -Operator eq -Value 100 -BackgroundColor Red
                    TableConditionalFormatting -Name 'Memory (%)' -ComparisonType number -Operator gt -Value 70 -BackgroundColor Yellow
                    TableConditionalFormatting -Name 'Memory (%)' -ComparisonType number -Operator gt -Value 90 -BackgroundColor Red
                    TableConditionalFormatting -Name 'Memory (%)' -ComparisonType number -Operator eq -Value 100 -BackgroundColor Red
                }
            }
        }
    }
}

# Build SD HTML report
$header = Write-SDDashboardHeader
$body_1 = Write-SDDashboardBody
$body_2 = ""
$sd_session_table = $session_table | Sort-Object Customer
$body_content = foreach ($s in $sd_session_table){
    if($s."Avg Load (%)" -gt "90"){
        $body_2 += ('<div><div class="header-background"><span class="header-text">') + ($s.Customer) + ('</span><span class="dot-red"></span></div><div class="box-text"> Connected: ') + ($s.Connected) + ('<br> Disconnected: ') + ($s."Disconn.") + ('<br> Servers: ') + ($s.Servers) + ('<br> Avg. Load: ') + ($s."Avg Load (%)") + ("%") + ('<br> Avg. Sessions: ') + ($s."Avg Sessions") + ('</div></div>')
    }
    else{
        $body_2 += ('<div><div class="header-background"><span class="header-text">') + ($s.Customer) + ('</span><span class="dot-green"></span></div><div class="box-text"> Connected: ') + ($s.Connected) + ('<br> Disconnected: ') + ($s."Disconn.") + ('<br> Servers: ') + ($s.Servers) + ('<br> Avg. Load: ') + ($s."Avg Load (%)") + ("%") + ('<br> Avg. Sessions: ') + ($s."Avg Sessions") + ('</div></div>')
    }
}
$body_3 = Write-SDDashboardEnd
$sddashboard = $header + $body_1 + $body_2 + $body_3
$sddashboard | Out-File -FilePath $sd_html_path
