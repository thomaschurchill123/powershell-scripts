<#
    .SYNOPSIS
          Report on outdated NetScaler backups.

    .DESCRIPTION
          Checks to see if any NS backups are older than three months, will then email the Citrix team
          distribution list to prompt for up to date backups to be taken.

    .NOTES
        	Version:        1.0
        	Author:         Thomas Churchill
        	Creation Date:  08/02/19
        	Purpose/Change: Initial script development
#>

#Variables
$date_range = (Get-Date).AddDays(-93)
$netscaler_backup_location = "E:\NetScaler Backups\"
$netscaler_backup_files = Get-ChildItem -Path $netscaler_backup_location -Filter *.tgz
$email_params = @{
  From = "emailsender"
  To = "emailrecipient"
  Subject = "NetScaler Backup Status"
  BodyAsHtml = "The following NetScaler backups are older than three months:<br>"
  SmtpServer = "smtpserverip"
}
$counter = 0
#Main Script
foreach($file in $netscaler_backup_files){
  $file_name = $file.Name
  $file_date = $file.LastWriteTime
  if($file_date -lt $date_range){
    $email_params.BodyAsHtml += "$file_name <br>"
    $counter++
  }
}
$email_params.BodyAsHtml += "<br><br>These backups are located in $netscaler_backup_location on the PVS servers.<br>"
$email_params.BodyAsHtml += "Please create new backups of the relevant devices and delete/archive the above."
if($counter -gt 0){
     Send-MailMessage @email_params
}
