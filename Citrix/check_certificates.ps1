<#
.SYNOPSIS
        Get info on certificates from key servers.
.Description
        Queries a list of servers for certificates in the personal store that are going to expire in the current year.
        Then outputs a list of certs to a report. This is designed to be run ad-hoc.
.Notes
        Author - Thomas Churchill; Version - 1.0; Date - 17/01/2019
#>
#Parameters
param([Parameter(Mandatory=$True)][string]$ExportPath)
#Variables
$server_list_path = "C:\scripts\CoreServerList.csv"
$server_list = Import-Csv -path $server_list_path
$date_year = Get-Date -Format yyyy #Get the current year to check against certificates.

#Main Script 
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