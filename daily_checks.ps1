<#
	 .SYNOPSIS
			 Create and email report for daily Citrix infrastructure checks.

	 .DESCRIPTION
			 Collects information on critical Citrix services and database connections and
       formats the information into a HTML coded email to be distributed to key members of staff.

	 .NOTES
	 		 Version:        2.0
			 Author:         Thomas Churchill
			 Creation Date:  28/02/19
			 Purpose/Change: Added run down of delivery groups.
#>
#Functions
function Test-Services{
param([string[]]$services,[string]$computername)
    $service_counter = $null
    foreach($service in $services){
    $service_test = Get-Service -ComputerName $computername -Name $service
    $service_display_name = $service_test.DisplayName
        if($service_test.Status -eq "Running"){
        Write-Host -ForegroundColor Green "$service_display_name okay!"
        $service_counter++
                    }
        else{
         Write-Host -ForegroundColor Red "$service_display_name down/server not contactable."
            }
               }
}
function Get-DGTotalServers{
            param([string]$DGID,[string]$DCName)
            Get-BrokerMachine -AdminAddress $DCName | Where-Object {$_.DesktopGroupUid -eq "$DGID"}
        }
# Load snapins
if ((Get-PSSnapin "Citrix.Broker.Admin.*" -EA silentlycontinue) -eq $null) {
try { Add-PSSnapin Citrix.Broker.Admin.* -ErrorAction Stop }
catch { write-error "Error Get-PSSnapin Citrix.Broker.Admin.* Powershell snapin"; Return }
}
#Variables
$ErrorActionPreference = 'Stop'
$server_list = Import-Csv -Path C:\Scripts\CoreServerList\CoreServerList.csv
$customer_matrix = Import-Csv -Path C:\Scripts\CustomerMatrix\customermatrix.csv
$date = Get-Date -Format "dd/MM/yyyy HH:mm"
$log_date = Get-Date -Format yyyy_MM_dd_HH_mm
$log_path = "C:\scripts\daily_checks\daily_checks_$log_date.log"
$email_params = @{
  From = "SendingEmailAddress";
  To = "Recipients";
  Subject = "Citrix Daily Checks - $date";
  BodyAsHtml = @"
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
 <head>
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
  <title>Citrix Daily Checks</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
 </head>
</html>
<body style="margin: 0; padding:0;">
<font face="Tahoma">
  <table border="0" cellpadding="0" cellspacing="0" width="100%">
    <tr>
      <td>
        <table align="center" border="0" cellpadding="0" width="600" style="border-collapse: collapse;">
          <tr>
            <td align="center" bgcolor="#70bbd9" style="padding: 40px 0 30px 0;">
            <img width="250" height="94" alt="Citrix" src="citrix-logo-black.png"<br>
        <Font face="Tahoma" size="2">
      </td>
          </tr>
          <tr>
            <td bgcolor="#ffffff" style="padding: 40px 30px 40px 30px;">
              <table border="0" cellpadding="0" cellspacing="0" width="100%">
                <tr>
                  <td align="center">
                    <font face="Tahoma" size="4"><b>Daily Citrix Infrastructure Service Report,<br>
                      $Date<br></b>
                  </td>
                </tr>
                &nbsp;
                <tr>
                </tr>
                <tr>
                  <td>
                    <table border="0" cellpadding="0" cellspacing="0" width ="100%">
                      <tr>
                        <td width="250" valign="top" align="center">
                          <font face="Tahoma"><b>Server</b>
                        </td>
                        <td width="250" valign="top" align="center">
                          <font face="Tahoma"><b>Services</b>
                        </td>
                      </tr>
"@;
  SmtpServer = "smtpserverip";
  Attachments = "C:\scripts\daily_checks\citrix-logo-black.png"}
$delivery_controller_services = (
"CitrixBrokerService",
"CitrixADIdentityService",
"CitrixConfigurationService"
)
$director_services = (
"IISAdmin",
"W3SVC"
)
$pvs_services = (
"DHCPServer",
"BNTFTP")
$storefront_services = (
"W3SVC"
)
$license_services = (
"Citrix Licensing",
"Citrix_GTLicensingProv",
"CitrixWebServicesforLicensing"
)
#Main script
Start-Transcript -Path $log_path
Write-Host "======================="
Write-Host "Script starting @ $log_date"
Write-Host "======================="
#Delivery Controller Checks
Write-Host -ForegroundColor Yellow "Starting Delivery Controller checks"
#Delivery Controller checks
foreach($dc in $server_list.Where({$_.Role -eq 'Delivery_Controller'})){
    $dc_fqdn = $dc.FQDN
    Write-Host -ForegroundColor Yellow "Service status for $dc_fqdn"
    . Test-Services -services $delivery_controller_services -computername $dc_fqdn
    $delivery_controller_services_count = $delivery_controller_services.count
    $email_params.BodyAsHtml += @"
                        <tr>
                        <td align="center">
                            <font face="Tahoma">$dc_fqdn
                        </td>
                        <td align="center">
                            <font face="Tahoma">$service_counter/$delivery_controller_services_count
                        </td>
                        </tr>
"@
}
#End of Delivery Controller checks
#Director Checks
Write-Host -ForegroundColor Yellow "Starting Citrix Director checks"
foreach($director in $server_list.Where({$_.Role -eq "Director"})){
    $director_fqdn = $director.FQDN
    Write-Host -ForegroundColor Yellow "Service status for $director_fqdn"
    . Test-Services -services $director_services -computername $director_fqdn
    $director_services_count = $director_services.count
    $email_params.BodyAsHtml += @"
                        <tr>
                        <td align="center">
                            <font face="Tahoma">$director_fqdn
                        </td>
                        <td align="center">
                            <font face="Tahoma">$service_counter/$director_services_count
                        </td>
                        </tr>
"@
}
#End of Director Checks
#PVS Checks
Write-Host -ForegroundColor Yellow "Starting Citrix PVS checks"
foreach($pvs in $server_list.Where({$_.Role -eq "PVS"})){
    $pvs_fqdn = $pvs.FQDN
    Write-Host -ForegroundColor Yellow "Service status for $pvs_fqdn"
    . Test-Services -services $pvs_services -computername $pvs_fqdn
    $pvs_services_count = $pvs_services.count
    $email_params.BodyAsHtml += @"
                        <tr>
                        <td align="center">
                            <font face="Tahoma">$pvs_fqdn
                        </td>
                        <td align="center">
                            <font face="Tahoma">$service_counter/$pvs_services_count
                        </td>
                        </tr>
"@
}
#End of PVS Checks
#StoreFront Checks
Write-Host -ForegroundColor Yellow "Starting Citrix StoreFront checks"
foreach($storefront in $server_list.Where({$_.Role -eq "StoreFront"})){
    $storefront_fqdn = $storefront.FQDN
    Write-Host -ForegroundColor Yellow "Service status for $storefront_fqdn"
    . Test-Services -services $storefront_services -computername $storefront_fqdn
    $storefront_services_count = $storefront_services.count
    $email_params.BodyAsHtml += @"
                        <tr>
                        <td align="center">
                            <font face="Tahoma">$storefront_fqdn
                        </td>
                        <td align="center">
                            <font face="Tahoma">$service_counter/$storefront_services_count
                        </td>
                        </tr>
"@
}
#End of StoreFront Checks
#Licensing Server Checks
Write-Host -ForegroundColor Yellow "Starting Citrix Licensing checks"
foreach($license in $server_list.Where({$_.Role -eq "License"})){
    $license_fqdn = $license.FQDN
    Write-Host -ForegroundColor Yellow "Service status for $license_fqdn"
    . Test-Services -services $license_services -computername $license_fqdn
    $license_services_count = $license_services.count
    $email_params.BodyAsHtml += @"
                        <tr>
                        <td align="center">
                            <font face="Tahoma">$license_fqdn
                        </td>
                        <td align="center">
                            <font face="Tahoma">$service_counter/$license_services_count
                        </td>
                        </tr>
"@
}
#End of Licensing Server Checks
$email_params.BodyAsHtml +=@"
                        <tr>
                        &nbsp;
                        </tr>
                    </table>
                  </td>
                </tr>
                <tr>
                  <td align="Center">
                  <font face="Tahoma" size="4"><b>Database Connectivity</b>
                  </td>
                </tr>
                <tr>
                &nbsp;
                </tr>
                <tr>
                    <td>
                      <table border="0" cellpadding="0" cellspacing="0" width="100%">
                        <tr>
                            <td width="250" valign="top" align="center">
                            <font face="Tahoma"><b>Server</b>
                            </td>
                            <td width="250" valign="top" align="center">
                            <font face="Tahoma"><b>Status</b>
                            </td>
                        </tr>
"@
#Database connectivity checks
Write-Host -ForegroundColor Yellow "Getting Database information from Delivery Controllers"
foreach($dc in $server_list.Where({$_.Role -eq 'Delivery_Controller'})){
    $dc_fqdn = $dc.FQDN
    $db_ifno = Get-BrokerDBConnection -AdminAddress $dc_fqdn
    if($db_ifno){
        Write-Host -ForegroundColor Green "Successfully queried DB info from $dc_fqdn"
        $email_params.BodyAsHtml +=@"
                          <tr>
                              <td align="center">
                              <font face="Tahoma">$dc_fqdn
                              </td>
                              <td align="center">
                              <font face="Tahoma">Active
                              </td>
                          </tr>
"@
        }
    else{
        Write-Host -ForegroundColor Red "Cannot retrieve DB info from $dc_fqdn"
        $email_params.BodyAsHtml +=@"
                          <tr>
                              <td align="center">
                              <font face="Tahoma">$dc_fqdn
                              </td>
                              <td align="center">
                              <font face="Tahoma">Down
                              </td>
                          </tr>
"@
    }
}
$email_params.BodyAsHtml += @"
        </table>
      </tr>
            <tr>
            &nbsp;
            </tr>
            <tr>
                <td align="center">
                <font face="Tahoma" size="4"><b>Delivery Group Status</b>
                </td>
            </tr>
            <tr>
            &nbsp;
            </tr>
            <tr>
                <td>
                    <table border="0" cellpadding="0" cellspacing="0" width="100%">
                     <tr>
                            <td width="250" valign="top" align="center">
                            <font face="Tahoma"><b>Delivery Group</b>
                            </td>
                            <td width="250" valign="top" align="center">
                            <font face="Tahoma"><b>Unregistered Machines</b>
                            </td>
                            <td width="250" valign="top" align="center">
                            <font face ="Tahoma"><b>Maintenance Mode</b>
                        </tr>

"@
#End of Database connectivity checks
#Delivery Group checks
Write-Host -ForegroundColor Yellow "Checking Delivery Groups"
foreach($customer in $customer_matrix){
    $customer_name  = $customer.customer
    $customer_deliverygroup_id = $customer.DeliveryGroupID
    $customer_delivery_controller = $customer.DeliveryController
    $customer_delivery_group_name = $customer.DeliveryGroup
    $delivery_group_total = (Get-DGTotalServers -DCName $customer_delivery_controller -DGID $customer_deliverygroup_id).count
    $unregistered_count = (Get-DGTotalServers -DCName $customer_delivery_controller -DGID $customer_deliverygroup_id | Where-Object {$_.RegistrationState -eq "Unregistered"}).count
    $maintenance_count = (Get-DGTotalServers -DCName $customer_delivery_controller -DGID $customer_deliverygroup_id | Where-Object {$_.InMaintenanceMode -eq "True"}).count
    if($unregistered_count -gt 0){
        Write-Host -ForegroundColor Red "$customer_name has $unregistered_count unregistered machines in $customer_delivery_group_name"
        $email_params.BodyAsHtml +=@"
                 <tr>
                    <td align="center">
                        <font face="Tahoma">$customer_name
                    </td>
                    <td align="center">
                        <font face="Tahoma">$unregistered_count/$delivery_group_total
                    </td>
                    <td align="center">
                        <font face="Tahoma">$maintenance_count/$delivery_group_total
                    </td>
                </tr>
"@
        }
    else{
        Write-Host -ForegroundColor Green "$customer_name has $unregistered_count unregistered machines in $customer_delivery_group_name"
        $email_params.BodyAsHtml +=@"
                 <tr>
                    <td align="center">
                        <font face="Tahoma">$customer_name
                    </td>
                    <td align="center">
                        <font face="Tahoma">$unregistered_count/$delivery_group_total
                    </td>
                    <td align="center">
                        <font face="Tahoma">$maintenance_count/$delivery_group_total
                    </td>
                </tr>
"@
    }

}
$email_params.BodyAsHtml +=@"
    </table>
    </tr>
"@
#End of Delivery Group checks
#Send email report
$hostname = hostname
$unc = ("\\")+($hostname)+("\c$\")
$script_root = $PSScriptRoot
$script_path = $script_root.Replace("C:\","$unc")
$email_params.BodyAsHtml +=@"
              </table>
            </td>
          </tr>
          <tr>
            <td bgcolor="#ee4c50" style="padding: 40px">
              <font face="Tahoma">Diagnosic information can be found in:
              $script_path
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
  </font>
</body>
"@
Send-MailMessage @email_params

#Log Clean Up
Write-Host -ForegroundColor Yellow "Checking for old logs.."
$limit = (Get-Date).AddDays(-93)
$old_logs_check = Get-ChildItem -Path $log_path *.log | Where-Object {$_.LastWriteTime -lt $limit}
if($old_logs_check){
    Write-Host -ForegroundColor Yellow "Old log files detected, deleting..."
    try {
    $old_logs_check | Remove-Item
    }
    catch{
    $error_message = $_.Exception.Message
    Write-Host -ForegroundColor Red "Failed to clean up old logs error:"
    $error_message
    }
}
else{
    Write-Host -ForegroundColor Green "No old logs detected."
}
Write-Host "======================="
Write-Host "Script Finished"
Write-Host "======================="
Stop-Transcript
