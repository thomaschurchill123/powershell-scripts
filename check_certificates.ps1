<#
	 .SYNOPSIS
			 Get personal certifcates that will expire this year.

	 .DESCRIPTION
			 This script queries the personal certificate stores of a pre-defined list of servers
       (relying on network connectivity) and returns details on the certificates that expire in
       the same year the script was run.

	 .EXAMPLE
			 ./check_certificates.ps1 -ExportPath C:\Reports\Cert_Report.csv

	 .NOTES
      Version:        1.0
      Author:         Thomas Churchill
      Creation Date:  17/01/19
      Purpose/Change: Initial script development

#>
#Parameters
param(
  <#
  .PARAMETER ExportPath
      Provide the path where the report (csv) should be exported to.
  #>
  [Parameter(Mandatory=$True)][string]$ExportPath
)
param(
  <#
  .PARAMETER ServerList
      Provide the path to the list of servers to check (csv).
  #>
  [Parameter(Mandatory=$True)][string]$ServerList
)
#Variables
$ErrorActionPreference = "stop"
$server_list = Import-Csv -path $ServerList
$date_year = Get-Date -Format yyyy #Get the current year to check against certificates.
$log_date = Get-Date -Format "yyyy-MM"
$log_path = "$PSScriptRoot/check_certificates_$log_date.log"
#Main Script
Start-Transcript -Path $log_path
$report = foreach($server in $server_list){
  $server_fqdn = $server.fqdn
  $certificate_list = Invoke-Command -ComputerName $server_fqdn -ScriptBlock {
    Get-ChildItem -Path "cert:\localmachine\my"
  }
   foreach($cert in $certificate_list){
  $cert_subject = $cert.Subject
  $cert_expire = $cert.NotAfter
  [PSCustomObject]@{
    Server = $server_fqdn
    Certificate_Subject = $cert_subject
    Certificate_Expiry_Date = $cert_expire
    }
  }
}

#Export report
$report | Where-Object {$_.Certificate_Expiry_Date -like "*$date_year*"} | Export-Csv -Path $ExportPath -nti -NoClobber
Stop-Transcript
